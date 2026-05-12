class RecurringJobDispatcherJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 50

  def perform
    sync_missing_schedules!
    release_stale_locks!
    dispatch_due_schedules!
  end

  private

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

  def release_stale_locks!
    RecurringJobSchedule.locked_stale.update_all(locked_at: nil, locked_by: nil, updated_at: Time.current)
  end

  def dispatch_due_schedules!
    RecurringJobSchedule.transaction do
      RecurringJobSchedule
        .due
        .where(locked_at: nil)
        .order(Arel.sql("COALESCE(run_requested_at, next_run_at) ASC"), :id)
        .limit(BATCH_SIZE)
        .lock("FOR UPDATE SKIP LOCKED")
        .each { dispatch_schedule!(_1) }
    end
  end

  def dispatch_schedule!(schedule)
    if !schedule.allow_overlap? && schedule.running_run?
      schedule.update!(
        next_run_at: schedule.next_run_after,
        run_requested_at: nil,
        last_status: "skipped",
        last_error_message: "Previous run is still running"
      )
      return
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

    job = RecurringJobRunnerJob.set(queue: schedule.queue_name).perform_later(run.id)
    run.update!(active_job_id: job.job_id)
    schedule.update!(
      last_enqueued_at: now,
      next_run_at: schedule.next_run_after(now),
      run_requested_at: nil,
      last_status: "enqueued",
      last_error_message: nil,
      locked_at: now,
      locked_by: run.public_id
    )
  end
end
