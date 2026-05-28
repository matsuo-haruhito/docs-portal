class Admin::RecurringJobSchedulesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_schedule, only: %i[show request_run]

  def index
    RecurringJobDispatcherJob.perform_now if params[:sync_definitions].present?
    @schedules = RecurringJobSchedule.order(:job_key)
  end

  def show
    @runs = @schedule.recurring_job_runs.order(scheduled_at: :desc, id: :desc).limit(50)
  end

  def request_run
    @schedule.update!(run_requested_at: Time.current)
    RecurringJobDispatcherJob.perform_later
    redirect_to admin_recurring_job_schedule_path(@schedule, return_to: @return_to_path), notice: "定期ジョブの即時実行を要求しました。"
  end

  private

  def set_schedule
    @schedule = RecurringJobSchedule.find_by!(public_id: params[:public_id])
    @return_to_path = safe_return_to_path(admin_recurring_job_schedules_path)
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return_to.start_with?("/") ? return_to : fallback
  end
end
