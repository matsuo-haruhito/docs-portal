class Admin::RecurringJobSchedulesController < Admin::BaseController
  DEFAULT_RUN_HISTORY_PER_PAGE = 50
  MAX_RUN_HISTORY_PER_PAGE = 100
  SCHEDULE_QUERY_MAX_LENGTH = 100
  RUN_QUERY_MAX_LENGTH = SCHEDULE_QUERY_MAX_LENGTH
  GIT_IMPORT_OPERATIONS_LIMIT = 20

  before_action :require_admin_only!
  before_action :set_schedule, only: %i[show request_run]

  def index
    @schedule_status_options = recurring_job_status_options
    @schedule_enabled_options = recurring_job_enabled_options
    @selected_status = schedule_status_param
    @selected_enabled = schedule_enabled_param
    @selected_query = schedule_query_param
    @triage_status_counts = RecurringJobSchedule.group(:last_status).count
    @schedules = RecurringJobSchedule.order(:job_key)
    @schedules = filter_schedules_by_enabled(@schedules, @selected_enabled) if @selected_enabled.present?
    @schedules = filter_schedules_by_status(@schedules, @selected_status) if @selected_status.present?
    @schedules = filter_schedules_by_query(@schedules, @selected_query) if @selected_query.present?
  end

  def sync_definitions
    RecurringJobDispatcherJob.perform_now
    redirect_to admin_recurring_job_schedules_path, notice: "定期ジョブ定義を同期しました。"
  end

  def show
    @run_status_options = recurring_job_run_status_options
    @selected_run_status = run_status_param
    @selected_run_query = run_query_param
    @selected_scheduled_from = scheduled_from_param
    @selected_scheduled_to = scheduled_to_param
    @run_page = run_history_page_param
    @run_per_page = run_history_per_page_param
    @run_filter_warnings = []

    scheduled_from = parsed_run_time(@selected_scheduled_from, label: "予定時刻(開始)", beginning: true)
    scheduled_to = parsed_run_time(@selected_scheduled_to, label: "予定時刻(終了)", end_of_day: true)

    runs_scope = @schedule.recurring_job_runs
    @run_status_counts = runs_scope.group(:status).count
    runs_scope = runs_scope.where(status: @selected_run_status) if @selected_run_status.present?
    runs_scope = filter_runs_by_query(runs_scope, @selected_run_query) if @selected_run_query.present?
    runs_scope = runs_scope.where("scheduled_at >= ?", scheduled_from) if scheduled_from
    runs_scope = runs_scope.where("scheduled_at <= ?", scheduled_to) if scheduled_to

    @runs_total_count = runs_scope.count
    @runs_total_pages = [(@runs_total_count.to_f / @run_per_page).ceil, 1].max
    @run_page = @runs_total_pages if @run_page > @runs_total_pages
    @run_offset = (@run_page - 1) * @run_per_page
    @runs = runs_scope.order(scheduled_at: :desc, id: :desc).offset(@run_offset).limit(@run_per_page)

    load_git_import_operations if git_import_schedule?
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

  def git_import_schedule?
    @schedule.job_key == "sync_git_import_sources"
  end

  def load_git_import_operations
    @git_import_sources = GitImportSource.includes(:project).order(:repository_full_name, :branch, :source_path)
    @recent_git_import_runs = GitImportRun
      .includes(git_import_source: :project)
      .where(import_mode: :pull)
      .order(created_at: :desc, id: :desc)
      .limit(GIT_IMPORT_OPERATIONS_LIMIT)
    @recent_git_import_publish_jobs = PublishJob
      .where(source_repo: @git_import_sources.map(&:repository_full_name).uniq)
      .order(created_at: :desc, id: :desc)
      .limit(GIT_IMPORT_OPERATIONS_LIMIT)
    @git_import_preview_status_counts = DocumentVersion.where(snapshot_kind: "git_import").group(:preview_build_status).count
    @recent_git_import_versions = DocumentVersion
      .includes(:document)
      .where(snapshot_kind: "git_import")
      .order(created_at: :desc, id: :desc)
      .limit(GIT_IMPORT_OPERATIONS_LIMIT)
  end

  def recurring_job_status_options
    [["すべて", ""]] + recurring_job_status_values.map do |status|
      [recurring_job_status_label(status), status]
    end
  end

  def recurring_job_enabled_options
    [["すべて", ""], ["有効", "true"], ["無効", "false"]]
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

  def schedule_enabled_param
    enabled = params[:enabled].to_s
    %w[true false].include?(enabled) ? enabled : nil
  end

  def schedule_query_param
    params[:q].to_s.strip.presence&.slice(0, SCHEDULE_QUERY_MAX_LENGTH)
  end

  def run_status_param
    status = params[:run_status].to_s
    RecurringJobRun.statuses.key?(status) ? status : nil
  end

  def run_query_param
    params[:q].to_s.strip.presence&.slice(0, RUN_QUERY_MAX_LENGTH)
  end

  def scheduled_from_param
    params[:scheduled_from].to_s.strip.presence
  end

  def scheduled_to_param
    params[:scheduled_to].to_s.strip.presence
  end

  def run_history_page_param
    value = params[:page].to_i
    value.positive? ? value : 1
  end

  def run_history_per_page_param
    value = params[:per_page].to_i
    return DEFAULT_RUN_HISTORY_PER_PAGE unless value.positive?

    [value, MAX_RUN_HISTORY_PER_PAGE].min
  end

  def filter_schedules_by_enabled(scope, enabled)
    scope.where(enabled: enabled == "true")
  end

  def filter_schedules_by_status(scope, status)
    return scope.where(last_status: [nil, ""]) if status == "not_run"

    scope.where(last_status: status)
  end

  def filter_schedules_by_query(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(job_key) LIKE :query OR LOWER(job_class) LIKE :query OR LOWER(queue_name) LIKE :query OR LOWER(COALESCE(last_error_message, '')) LIKE :query",
      query: like_query
    )
  end

  def filter_runs_by_query(scope, query)
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(COALESCE(active_job_id, '')) LIKE :query OR LOWER(COALESCE(error_message, '')) LIKE :query",
      query: like_query
    )
  end

  def parsed_run_time(value, label:, beginning: false, end_of_day: false)
    return if value.blank?
    raw_value = value.to_s.strip
    return invalid_run_time_filter(label, value) unless raw_value.match?(/\d/)
    time = Time.zone.parse(raw_value)
    return invalid_run_time_filter(label, value) unless time
    return time.beginning_of_day if beginning && raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    return time.end_of_day if end_of_day && raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    time
  rescue ArgumentError, TypeError
    invalid_run_time_filter(label, value)
  end

  def invalid_run_time_filter(label, value)
    @run_filter_warnings ||= []
    @run_filter_warnings << "#{label}「#{value}」は日時として解釈できないため、この条件は適用していません。"
    nil
  end
end
