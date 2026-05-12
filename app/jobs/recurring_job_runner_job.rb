class RecurringJobRunnerJob < ApplicationJob
  queue_as :default

  def perform(recurring_job_run_id)
    run = RecurringJobRun.find(recurring_job_run_id)
    schedule = run.recurring_job_schedule
    mark_started!(run, schedule)

    job_class = run.job_class.safe_constantize
    raise NameError, "Recurring job class is not found: #{run.job_class}" if job_class.blank?

    job_class.perform_now(**run.args_json.symbolize_keys)
    mark_completed!(run, schedule)
  rescue => e
    mark_failed!(run, schedule, e) if defined?(run) && run
    raise
  ensure
    unlock_schedule!(schedule) if defined?(schedule) && schedule
  end

  private

  def mark_started!(run, schedule)
    now = Time.current
    run.update!(status: :running, started_at: now)
    schedule.update!(last_started_at: now, last_status: "running", last_error_message: nil)
  end

  def mark_completed!(run, schedule)
    now = Time.current
    run.update!(status: :completed, finished_at: now, error_message: nil)
    schedule.update!(last_finished_at: now, last_status: "completed", last_error_message: nil)
  end

  def mark_failed!(run, schedule, error)
    now = Time.current
    run.update!(status: :failed, finished_at: now, error_message: error.message)
    schedule.update!(last_finished_at: now, last_status: "failed", last_error_message: error.message)
  end

  def unlock_schedule!(schedule)
    schedule.update!(locked_at: nil, locked_by: nil)
  end
end
