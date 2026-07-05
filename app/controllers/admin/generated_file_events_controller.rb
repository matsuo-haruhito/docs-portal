class Admin::GeneratedFileEventsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_event, only: %i[show retry_dispatch]

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100
  QUERY_MAX_LENGTH = 100
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def index
    @filters = event_filter_params
    @filter_warnings = []
    @page = page_param
    @per_page = per_page_param
    @status_counts = GeneratedFileEvent.group(:status).count
    @filtered_generated_file_events = apply_filters(GeneratedFileEvent.order(created_at: :desc, id: :desc))
    @bulk_retry_target_count = bulk_retry_target_scope.size
    @total_count = @filtered_generated_file_events.count
    @total_pages = total_pages(@total_count)
    @page = normalized_page(@page, @total_pages)
    @generated_file_events = @filtered_generated_file_events.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @related_generated_file_runs = recent_runs_related_to(@generated_file_event.public_id)
  end

  def retry_dispatch
    if read_only_maintenance_mode?
      redirect_to admin_generated_file_event_path(@generated_file_event.public_id, return_to: @return_to_path), alert: maintenance_retry_message
      return
    end

    reset_for_dispatch!(@generated_file_event)
    GeneratedFileEventDispatchJob.perform_later

    redirect_to admin_generated_file_event_path(@generated_file_event.public_id, return_to: @return_to_path), notice: "生成ファイルイベントの再投入をキューに投入しました。"
  end

  def retry_failed
    @filters = event_filter_params
    @filter_warnings = []

    if read_only_maintenance_mode?
      redirect_to admin_generated_file_events_path(@filters), alert: maintenance_retry_message
      return
    end

    events = bulk_retry_target_scope.to_a
    events.each { reset_for_dispatch!(_1) }
    GeneratedFileEventDispatchJob.perform_later if events.any?

    redirect_to admin_generated_file_events_path(@filters), notice: "失敗した生成ファイルイベント #{events.size} 件の再投入をキューに投入しました。"
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

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_retry_message
    "メンテナンス中のため生成ファイルイベントの再投入は停止しています。イベント一覧・詳細は閲覧できます。運用手順は本番運用・インフラ前提を確認してください。"
  end

  def recent_runs_related_to(public_id)
    metadata_filter = {generated_file_event_public_ids: [public_id]}.to_json

    GeneratedFileRun
      .where("metadata::jsonb @> ?::jsonb", metadata_filter)
      .order(created_at: :desc, id: :desc)
      .limit(10)
  end

  def bulk_retry_target_scope
    apply_filters(GeneratedFileEvent.failed.order(created_at: :asc, id: :asc)).limit(MAX_PER_PAGE)
  end

  def apply_filters(scope)
    filters = @filters || {}
    scope = scope.public_send(filters[:status]) if filters[:status].in?(GeneratedFileEvent.statuses.keys)
    scope = scope.where(operation: filters[:operation]) if filters[:operation].present?
    scope = scope.where(event_source: filters[:event_source]) if filters[:event_source].present?
    scope = scope.where("path LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(normalized_path_filter(filters[:path]))}%") if filters[:path].present?
    scope = apply_query_filter(scope, filters[:q]) if filters[:q].present?

    scheduled_from = parsed_time(filters[:scheduled_from], label: "実行予定日(開始)", beginning: true)
    scheduled_to = parsed_time(filters[:scheduled_to], label: "実行予定日(終了)", end_of_day: true)
    scope = scope.where("scheduled_at >= ?", scheduled_from) if scheduled_from
    scope = scope.where("scheduled_at <= ?", scheduled_to) if scheduled_to
    scope
  end

  def apply_query_filter(scope, query)
    normalized_query = normalized_text_filter(query)
    escaped_query = ActiveRecord::Base.sanitize_sql_like(normalized_query.to_s)
    escaped_path_query = ActiveRecord::Base.sanitize_sql_like(normalized_path_filter(normalized_query))

    scope.where(
      "public_id LIKE :query OR path LIKE :path_query OR error_message LIKE :query",
      query: "%#{escaped_query}%",
      path_query: "%#{escaped_path_query}%"
    )
  end

  def event_filter_params
    filters = params.permit(:status, :operation, :event_source, :path, :scheduled_from, :scheduled_to, :q).to_h.symbolize_keys
    filters[:q] = normalized_text_filter(filters[:q])
    filters[:path] = normalized_text_filter(filters[:path])
    filters.compact_blank
  end

  def normalized_text_filter(value)
    value.to_s.squish.first(QUERY_MAX_LENGTH).presence
  end

  def normalized_path_filter(value)
    normalized_text_filter(value).to_s.tr("\\", "/")
  end

  def page_param
    [params[:page].to_i, 1].max
  end

  def normalized_page(page, total_pages)
    page.clamp(1, total_pages)
  end

  def per_page_param
    requested = params[:per_page].presence&.to_i || DEFAULT_PER_PAGE
    requested.clamp(1, MAX_PER_PAGE)
  end

  def total_pages(count)
    [(count.to_f / @per_page).ceil, 1].max
  end

  def parsed_time(value, label:, beginning: false, end_of_day: false)
    return if value.blank?

    raw_value = value.to_s.strip
    return invalid_time_filter(label, value) unless raw_value.match?(/\d/)

    time = Time.zone.parse(raw_value)
    return invalid_time_filter(label, value) unless time
    return time.beginning_of_day if beginning && raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    return time.end_of_day if end_of_day && raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    time
  rescue ArgumentError, TypeError
    invalid_time_filter(label, value)
  end

  def invalid_time_filter(label, value)
    @filter_warnings ||= []
    @filter_warnings << "#{label}「#{value}」は日時として解釈できないため、この条件は適用していません。"
    nil
  end

  def set_generated_file_event
    @generated_file_event = GeneratedFileEvent.find_by!(public_id: params[:public_id])
    @return_to_path = safe_return_to_path(admin_generated_file_events_path)
  end

  def safe_return_to_path(fallback)
    return_to = params[:return_to].to_s
    return_to.start_with?("/") && !return_to.start_with?("//") ? return_to : fallback
  end
end
