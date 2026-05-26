class Admin::RecurringJobSchedulesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_schedule, only: %i[show request_run]

  SCHEDULE_STATUS_FILTERS = (%w[pending] + RecurringJobRun.statuses.keys).freeze
  RUN_STATUS_FILTERS = RecurringJobRun.statuses.keys.freeze

  def index
    RecurringJobDispatcherJob.perform_now if params[:sync_definitions].present?
    @filters = schedule_filter_params
    @status_options = SCHEDULE_STATUS_FILTERS
    @status_counts = RecurringJobSchedule.group(:last_status).count
    @schedules = apply_schedule_filters(RecurringJobSchedule.order(:job_key))
  end

  def show
    @run_filters = run_filter_params
    @run_status_options = RUN_STATUS_FILTERS
    @runs = apply_run_filters(@schedule.recurring_job_runs.order(scheduled_at: :desc, id: :desc)).limit(50)
  end

  def request_run
    @schedule.update!(run_requested_at: Time.current)
    RecurringJobDispatcherJob.perform_later
    redirect_to admin_recurring_job_schedule_path(@schedule), notice: "定期ジョブの即時実行を要求しました。"
  end

  private

  def apply_schedule_filters(scope)
    status = @filters[:status].to_s
    return scope unless status.in?(SCHEDULE_STATUS_FILTERS)

    scope.where(last_status: status)
  end

  def apply_run_filters(scope)
    status = @run_filters[:status].to_s
    return scope unless status.in?(RUN_STATUS_FILTERS)

    scope.where(status: status)
  end

  def schedule_filter_params
    params.permit(:status).to_h.symbolize_keys
  end

  def run_filter_params
    params.permit(:status).to_h.symbolize_keys
  end

  def set_schedule
    @schedule = RecurringJobSchedule.find_by!(public_id: params[:public_id])
  end
end