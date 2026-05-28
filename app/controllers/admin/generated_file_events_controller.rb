class Admin::GeneratedFileEventsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_event, only: %i[show retry_dispatch]

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100

  def index
    @filters = event_filter_params
    @page = page_param
    @per_page = per_page_param
    @status_counts = GeneratedFileEvent.group(:status).count
    @filtered_generated_file_events = apply_filters(GeneratedFileEvent.order(created_at: :desc, id: :desc))
    @total_count = @filtered_generated_file_events.count
    @total_pages = total_pages(@total_count)
    @generated_file_events = @filtered_generated_file_events.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @related_generated_file_runs = recent_runs_related_to(@generated_file_event.public_id)
  end

  def retry_dispatch
    reset_for_dispatch!(@generated_file_event)
    GeneratedFileEventDispatchJob.perform_later

    redirect_to admin_generated_file_event_path(@generated_file_event.public_id, return_to: @return_to_path), notice: "生成ファイルイベントの再dispatchをキューに投入しました。"
  end

  def retry_failed
    @filters = event_filter_params
    events = apply_filters(GeneratedFileEvent.failed.order(created_at: :asc, id: :asc)).limit(MAX_PER_PAGE)
    events.each { reset_for_dispatch!(_1) }
    GeneratedFileEventDispatchJob.perform_later if events.any?

    redirect_to admin_generated_file_events_path(@filters), notice: "失敗した生成ファイルイベント #{events.size} 件の再dispatchをキューに投入しました。"
  end

  private

  def reset_for_dispatch!(event)
    event.update!(
      status: :pending,
      scheduled_at: Time.current,
      error_message: nil,
      processed_at: nil
    )
  end

  def recent_runs_related_to(public_id)
    GeneratedFileRun
      .order(created_at: :desc, id: :desc)
      .limit(200)
      .select { |run| Array(run.metadata&.dig("generated_file_event_public_ids")).include?(public_id) }
      .first(10)
  end

  def apply_filters(scope)
    filters = @filters || {}
    scope = scope.public_send(filters[:status]) if filters[:status].in?(GeneratedFileEvent.statuses.keys)
    scope = scope.where(operation: filters[:operation]) if filters[:operation].present?
    scope = scope.where(event_source: filters[:event_source]) if filters[:event_source].present?
    scope = scope.where("path LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(normalized_path_filter(filters[:path]))}%") if filters[:path].present?

    scheduled_from = parsed_time(filters[:scheduled_from], beginning: true)
    scheduled_to = parsed_time(filters[:scheduled_to], end_of_day: true)
    scope = scope.where("scheduled_at >= ?", scheduled_from) if scheduled_from
    scope = scope.where("scheduled_at <= ?", scheduled_to) if scheduled_to
    scope
  end

  def event_filter_params
    params.permit(:status, :operation, :event_source, :path, :scheduled_from, :scheduled_to).to_h.symbolize_keys
  end

  def normalized_path_filter(value)
    value.to_s.tr("\\", "/")
  end

  def page_param
    [params[:page].to_i, 1].max
  end

  def per_page_param
    requested = params[:per_page].presence&.to_i || DEFAULT_PER_PAGE
    requested.clamp(1, MAX_PER_PAGE)
  end

  def total_pages(count)
    [(count.to_f / @per_page).ceil, 1].max
  end

  def parsed_time(value, beginning: false, end_of_day: false)
    return if value.blank?

    time = Time.zone.parse(value.to_s)
    return time.beginning_of_day if beginning && value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    return time.end_of_day if end_of_day && value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    time
  rescue ArgumentError, TypeError
    nil
  end

  def set_generated_file_event
    @generated_file_event = GeneratedFileEvent.find_by!(public_id: params[:public_id])
    @return_to_path = safe_return_to_path(admin_generated_file_events_path)
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return_to.start_with?("/") ? return_to : fallback
  end
end