class RecurringJobDispatcherJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50
  PREVIEW_STALE_RUNNING_AFTER = 30.minutes

  def perform
    sync_reliability_v2_schedule_state!
    sync_missing_schedules!
    recover_stale_enqueued_runs!
    recover_stale_preview_running_runs!
    release_stale_locks!
    dispatch_due_schedules!
  end

  private

  def sync_reliability_v2_schedule_state!
    gate_enabled = JobReliability::RolloutGate.enabled?

    RecurringJobSchedule.transaction do
      schedules = RecurringJobSchedule
        .where(job_key: RecurringJobDefinition.runner_protocol_v2_job_keys)
        .order(:id)
        .lock
        .to_a

      schedules.each do |schedule|
        if RecurringJobDefinition.rollout_gated_job_key?(schedule.job_key)
          sync_rollout_gated_schedule!(schedule, gate_enabled:)
        else
          restore_rollout_independent_schedule!(schedule)
        end
      end
    end
  end

  def sync_rollout_gated_schedule!(schedule, gate_enabled:)
    if gate_enabled
      restore_suspended_schedule!(schedule)
    else
      attributes = {enabled: false}
      if schedule.enabled_before_reliability_v2_suspend.nil?
        attributes[:enabled_before_reliability_v2_suspend] = schedule.enabled?
      end
      schedule.update!(attributes) if attributes.any? { |key, value| schedule.public_send(key) != value }
    end
  end

  def restore_rollout_independent_schedule!(schedule)
    restore_suspended_schedule!(schedule)
  end

  def restore_suspended_schedule!(schedule)
    return if schedule.enabled_before_reliability_v2_suspend.nil?

    schedule.update!(
      enabled: schedule.enabled_before_reliability_v2_suspend,
      enabled_before_reliability_v2_suspend: nil
    )
  end

  def sync_missing_schedules!
    RecurringJobDefinition.all.each do |definition|
      RecurringJobSchedule.find_or_create_by!(job_key: definition.job_key) do |schedule|
        schedule.job_class = definition.job_class
        schedule.queue_name = definition.queue_name
        schedule.interval_seconds = definition.interval_seconds || RecurringJobDefinition::DEFAULT_INTERVAL_SECONDS
        schedule.args_json = definition.args_json || {}
        schedule.description = definition.description
        schedule.enabled = definition.enabled
        schedule.allow_overlap = definition.allow_overlap
        schedule.next_run_at = Time.current
      end
    end
  end

  def recover_stale_enqueued_runs!
    execution_eligible(RecurringJobRun.stale_enqueued).find_each do |run|
      RecurringJobRun.transaction do
        run.lock!
        next unless run.enqueued?
        next unless run.enqueued_at.blank? || run.enqueued_at <= RecurringJobSchedule::STALE_LOCK_AFTER.ago

        schedule = run.recurring_job_schedule
        schedule.lock!
        now = Time.current
        run.update!(
          status: :failed,
          finished_at: now,
          error_message: RecurringJobRun::STALE_ENQUEUED_ERROR_MESSAGE
        )
        next unless schedule.locked_by == run.public_id

        schedule.update!(
          locked_at: nil,
          locked_by: nil,
          last_finished_at: now,
          last_status: "failed",
          last_error_message: RecurringJobRun::STALE_ENQUEUED_ERROR_MESSAGE
        )
      end
    end
  end

  def recover_stale_preview_running_runs!
    return if read_only_maintenance?

    RecurringJobRun
      .running
      .where(job_key: RecurringJobDefinition::DOCUSAURUS_PREVIEW_RECONCILIATION_JOB_KEY)
      .where("started_at IS NULL OR started_at <= ?", PREVIEW_STALE_RUNNING_AFTER.ago)
      .find_each do |run|
        recover_stale_preview_running_run!(run)
      end
  end

  def recover_stale_preview_running_run!(run)
    RecurringJobRun.transaction do
      run.lock!
      next unless run.running?
      next unless run.started_at.blank? || run.started_at <= PREVIEW_STALE_RUNNING_AFTER.ago

      schedule = run.recurring_job_schedule
      schedule.lock!
      next unless schedule.locked_by == run.public_id

      now = Time.current
      run.update!(
        status: :failed,
        finished_at: now,
        error_message: RecurringJobRun::STALE_RUNNING_ERROR_MESSAGE
      )
      schedule.update!(
        locked_at: nil,
        locked_by: nil,
        last_finished_at: now,
        last_status: "failed",
        last_error_message: RecurringJobRun::STALE_RUNNING_ERROR_MESSAGE
      )
    end
  end

  def release_stale_locks!
    execution_eligible(RecurringJobSchedule.locked_stale).find_each do |schedule|
      RecurringJobSchedule.transaction do
        schedule.lock!
        next unless schedule.locked_at && schedule.locked_at < RecurringJobSchedule::STALE_LOCK_AFTER.ago
        next if schedule.active_run?

        schedule.update!(locked_at: nil, locked_by: nil)
      end
    end
  end

  def dispatch_due_schedules!
    due_schedule_ids.each do |schedule_id|
      run = reserve_schedule_run(schedule_id)
      enqueue_run(run) if run
    end
  end

  def due_schedule_ids
    execution_eligible(RecurringJobSchedule.due.where(locked_at: nil))
      .order(Arel.sql("COALESCE(run_requested_at, next_run_at) ASC"), :id)
      .limit(BATCH_SIZE)
      .pluck(:id)
  end

  def reserve_schedule_run(schedule_id)
    RecurringJobSchedule.transaction do
      schedule = RecurringJobSchedule.where(id: schedule_id).lock("FOR UPDATE SKIP LOCKED").first
      next unless schedule&.due?
      next if schedule.locked_at.present?

      if !schedule.allow_overlap? && schedule.active_run?
        schedule.update!(next_run_at: schedule.next_run_after, run_requested_at: nil)
        next
      end

      now = Time.current
      run = schedule.recurring_job_runs.create!(
        job_key: schedule.job_key,
        job_class: schedule.job_class,
        queue_name: schedule.queue_name,
        args_json: schedule.args_json,
        status: :enqueued,
        scheduled_at: schedule.run_requested_at || schedule.next_run_at,
        enqueued_at: now
      )
      schedule.update!(
        last_enqueued_at: now,
        next_run_at: schedule.next_run_after(now),
        run_requested_at: nil,
        last_status: "enqueued",
        last_error_message: nil,
        locked_at: now,
        locked_by: run.public_id
      )
      run
    end
  end

  def enqueue_run(run)
    arguments = [run.id]
    if RecurringJobDefinition.runner_protocol_v2_job_key?(run.job_key)
      arguments << RecurringJobDefinition::V2_RUNNER_PROTOCOL_VERSION
    end
    job = RecurringJobRunnerJob.set(queue: run.queue_name).perform_later(*arguments)
    raise "Recurring job runner could not be enqueued" unless job

    run.update!(active_job_id: job.job_id)
  rescue StandardError => e
    fail_enqueue!(run, e)
    raise
  end

  def fail_enqueue!(run, error)
    RecurringJobRun.transaction do
      run.lock!
      return unless run.enqueued?

      schedule = run.recurring_job_schedule
      schedule.lock!
      now = Time.current
      run.update!(status: :failed, finished_at: now, error_message: error.message)
      return unless schedule.locked_by == run.public_id

      schedule.update!(
        locked_at: nil,
        locked_by: nil,
        last_finished_at: now,
        last_status: "failed",
        last_error_message: error.message
      )
    end
  end

  def execution_eligible(scope)
    scope = rollout_eligible(scope)
    return scope unless read_only_maintenance?

    scope.where.not(job_key: RecurringJobDefinition::DOCUSAURUS_PREVIEW_RECONCILIATION_JOB_KEY)
  end

  def rollout_eligible(scope)
    return scope if JobReliability::RolloutGate.enabled?

    scope.where.not(job_key: RecurringJobDefinition.rollout_gated_job_keys)
  end
end
