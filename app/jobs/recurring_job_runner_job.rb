class RecurringJobRunnerJob < ApplicationJob
  queue_as :default

  def perform(recurring_job_run_id, protocol_version = nil)
    run = RecurringJobRun.find(recurring_job_run_id)
    return if v2_run_blocked?(run, protocol_version)

    schedule = run.recurring_job_schedule
    claimed = claim_run!(run, schedule)
    return unless claimed

    job_class = run.job_class.safe_constantize
    raise NameError, "Recurring job class is not found: #{run.job_class}" if job_class.blank?

    job_class.perform_now(**run.args_json.symbolize_keys)
    mark_completed!(run, schedule)
  rescue StandardError => e
    mark_failed!(run, schedule, e) if claimed
    raise
  ensure
    unlock_schedule!(schedule, run) if claimed
  end

  private

  def v2_run_blocked?(run, protocol_version)
    return false unless RecurringJobDefinition.v2_job_key?(run.job_key)

    !JobReliability::RolloutGate.enabled? ||
      protocol_version != RecurringJobDefinition::V2_RUNNER_PROTOCOL_VERSION
  end

  def claim_run!(run, schedule)
    claimed = false

    RecurringJobRun.transaction do
      run.lock!
      schedule.lock!
      next unless run.enqueued?
      next unless schedule.locked_by == run.public_id

      now = Time.current
      run.update!(status: :running, started_at: now)
      schedule.update!(last_started_at: now, last_status: "running", last_error_message: nil)
      claimed = true
    end

    claimed
  end

  def mark_completed!(run, schedule)
    RecurringJobRun.transaction do
      run.lock!
      schedule.lock!
      return unless run.running?

      now = Time.current
      run.update!(status: :completed, finished_at: now, error_message: nil)
      schedule.update!(
        last_finished_at: now,
        last_status: "completed",
        last_error_message: nil,
        locked_at: nil,
        locked_by: nil
      ) if schedule.locked_by == run.public_id
    end
  end

  def mark_failed!(run, schedule, error)
    RecurringJobRun.transaction do
      run.lock!
      schedule.lock!
      return unless run.running?

      now = Time.current
      run.update!(status: :failed, finished_at: now, error_message: error.message)
      schedule.update!(
        last_finished_at: now,
        last_status: "failed",
        last_error_message: error.message,
        locked_at: nil,
        locked_by: nil
      ) if schedule.locked_by == run.public_id
    end
  end

  def unlock_schedule!(schedule, run)
    schedule.with_lock do
      schedule.update!(locked_at: nil, locked_by: nil) if schedule.locked_by == run.public_id
    end
  end
end
