class Admin::RecurringJobSchedulesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_schedule, only: %i[show request_run]

  def index
    RecurringJobDispatcherJob.perform_now if params[:sync_definitions].present?

    @schedule_status_options = recurring_job_status_options
    @selected_status = schedule_status_param
    @triage_status_counts = RecurringJobSchedule.group(:last_status).count
    @schedules = RecurringJobSchedule.order(:job_key)
    @schedules = filter_schedules_by_status(@schedules, @selected_status) if @selected_status.present?
  end

  def show
    @run_status_options = recurring_job_run_status_options
    @selected_run_status = run_status_param

    runs_scope = @schedule.recurring_job_runs
    @run_status_counts = runs_scope.group(:status).count
    runs_scope = runs_scope.where(status: @selected_run_status) if @selected_run_status.present?
    @runs = runs_scope.order(scheduled_at: :desc, id: :desc).limit(50)
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

  def recurring_job_status_options
    [["すべて", ""]] + recurring_job_status_values.map do |status|
      [recurring_job_status_label(status), status]
    end
  end

  def recurring_job_run_status_options
    [["すべて", ""]] + RecurringJobRun.statuses.keys.map do |status|
      [recurring_job_status_label(status), status]
    end
  end

  def recurring_job_status_values
    ["not_run"] + RecurringJobRun.statuses.keys
  end

  def recurring_job_status_label(status)
    I18n.t("labels.recurring_jobs.status.#{status}", default: status)
  end

  def schedule_status_param
    status = params[:status].to_s
    recurring_job_status_values.include?(status) ? status : nil
  end

  def run_status_param
    status = params[:run_status].to_s
    RecurringJobRun.statuses.key?(status) ? status : nil
  end

  def filter_schedules_by_status(scope, status)
    return scope.where(last_status: [nil, ""]) if status == "not_run"

    scope.where(last_status: status)
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return_to.start_with?("/") && !return_to.start_with?("//") ? return_to : fallback
  end
end
