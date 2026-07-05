class Admin::WebhookDeliveriesController < Admin::BaseController
  FAILED_DELIVERY_RETRY_LIMIT = Admin::WebhookEndpointsController::RECENT_DELIVERY_DISPLAY_LIMIT
  INDEX_DELIVERY_DISPLAY_LIMIT = 100
  FAILURE_HANDOFF_LIMIT = 20
  FAILURE_HANDOFF_THRESHOLD = 3
  FAILURE_HANDOFF_LOOKBACK_LIMIT = 200
  ERROR_QUERY_MAX_LENGTH = 100
  WEBHOOK_ENDPOINT_SEARCH_QUERY_MAX_LENGTH = 100
  WEBHOOK_ENDPOINT_SEARCH_LIMIT = 20
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"
  DELIVERY_STATUS_FILTERS = Admin::WebhookEndpointsController::DELIVERY_STATUS_FILTERS
  RETURN_DELIVERY_STATUS_FILTERS = (["all"] + DELIVERY_STATUS_FILTERS).freeze
  DATE_FILTER_LABELS = {
    created_from: "作成日From",
    created_to: "作成日To"
  }.freeze

  before_action :require_admin_only!
  before_action :set_webhook_delivery, only: %i[show retry_dispatch]
  before_action :set_delivery_return, only: %i[show retry_dispatch]

  def index
    @delivery_filters = delivery_search_filter_params
    @selected_webhook_endpoint = selected_webhook_endpoint_for_filter
    @delivery_filter_warnings = delivery_filter_warnings
    @delivery_filter_inputs = @delivery_filters.merge(invalid_delivery_date_filter_values)
    @delivery_filters_applied = @delivery_filters.values.any?(&:present?) || @delivery_filter_warnings.any?
    filtered_deliveries = filtered_index_delivery_scope

    @webhook_deliveries_total_count = filtered_deliveries.count
    @webhook_deliveries_limit = INDEX_DELIVERY_DISPLAY_LIMIT
    @webhook_deliveries_total_pages = [(@webhook_deliveries_total_count.to_f / @webhook_deliveries_limit).ceil, 1].max
    @webhook_deliveries_page = [delivery_history_page_param, @webhook_deliveries_total_pages].min
    @webhook_deliveries_offset = (@webhook_deliveries_page - 1) * @webhook_deliveries_limit
    @webhook_deliveries = filtered_deliveries.recent.offset(@webhook_deliveries_offset).limit(@webhook_deliveries_limit)
    @delivery_return_params = delivery_index_return_params(@delivery_filters, @webhook_deliveries_page)
  end

  def show
  end

  def retry_dispatch
    unless @webhook_delivery.failed?
      redirect_to @delivery_return_path, alert: "失敗していないWebhook送信履歴は再送できません。"
      return
    end

    unless @webhook_delivery.webhook_endpoint.active?
      redirect_to @delivery_return_path, alert: "停止中のWebhook設定には再送できません。"
      return
    end

    if read_only_maintenance_mode?
      redirect_to @delivery_return_path, alert: maintenance_retry_message
      return
    end

    WebhookDeliveryDispatcher.new.redeliver!(@webhook_delivery)
    redirect_to @delivery_return_path, notice: "Webhookを再送しました。結果は送信履歴で確認してください。"
  end

  def retry_failed
    unless params[:delivery_status].to_s == "failed"
      redirect_to admin_webhook_endpoints_path, alert: "まとめて再送は失敗のみ表示から実行してください。"
      return
    end

    if read_only_maintenance_mode?
      redirect_to admin_webhook_endpoints_path(delivery_status: "failed"), alert: maintenance_retry_message
      return
    end

    retryable_deliveries = current_failed_delivery_scope.select(&:retryable?)

    if retryable_deliveries.empty?
      redirect_to admin_webhook_endpoints_path(delivery_status: "failed"), alert: "再送可能なWebhook送信履歴はありません。"
      return
    end

    dispatcher = WebhookDeliveryDispatcher.new
    retryable_deliveries.each do |delivery|
      dispatcher.redeliver!(delivery)
    end

    redirect_to admin_webhook_endpoints_path(delivery_status: "failed"), notice: "Webhookを#{retryable_deliveries.size}件まとめて再送しました。結果は送信履歴で確認してください。"
  end

  def failure_alert_handoff
    entries = WebhookDeliveries::FailureAlertHandoff.new(
      threshold: FAILURE_HANDOFF_THRESHOLD,
      limit: FAILURE_HANDOFF_LIMIT + 1,
      lookback_limit: FAILURE_HANDOFF_LOOKBACK_LIMIT
    ).call
    visible_entries = entries.first(FAILURE_HANDOFF_LIMIT)

    render json: {
      current_filter: {
        threshold: FAILURE_HANDOFF_THRESHOLD,
        lookback_limit: FAILURE_HANDOFF_LOOKBACK_LIMIT
      },
      total_count: entries.size,
      limit: FAILURE_HANDOFF_LIMIT,
      truncated: entries.size > FAILURE_HANDOFF_LIMIT,
      note: failure_handoff_note(visible_entries),
      runbook_path: WebhookDeliveries::FailureAlertHandoff::RUNBOOK_PATH,
      candidates: visible_entries.map(&:to_h)
    }
  end

  def webhook_endpoint_search
    render json: { options: webhook_endpoint_options(searchable_webhook_endpoints) }
  end

  def selected_webhook_endpoint
    endpoint = WebhookEndpoint.find_by(id: params[:id])

    render json: { option: endpoint ? webhook_endpoint_option(endpoint) : nil }
  end

  private

  def set_webhook_delivery
    @webhook_delivery = WebhookDelivery.includes(:webhook_endpoint, :notification_event).find_by!(public_id: params[:public_id])
  end

  def set_delivery_return
    if params[:return_context].to_s == "deliveries_index"
      @delivery_return_filters = delivery_search_filter_params
      @delivery_return_page = delivery_history_page_param
      @delivery_return_params = delivery_index_return_params(@delivery_return_filters, @delivery_return_page)
      @delivery_return_path = admin_webhook_deliveries_path(@delivery_return_params.except(:return_context))
      @return_delivery_status = "all"
      @delivery_return_context = :deliveries_index
    else
      set_return_delivery_status
      @delivery_return_path = webhook_delivery_status_return_path
      @delivery_return_params = @return_delivery_status == "all" ? {} : { return_delivery_status: @return_delivery_status }
      @delivery_return_context = :webhook_endpoints
    end
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_retry_message
    "メンテナンス中のためWebhook再送は停止しています。送信履歴とfailure handoffは閲覧できます。運用手順は本番運用・インフラ前提を確認してください。"
  end

  def set_return_delivery_status
    requested_status = params[:return_delivery_status].to_s
    @return_delivery_status = RETURN_DELIVERY_STATUS_FILTERS.include?(requested_status) ? requested_status : "all"
  end

  def webhook_delivery_status_return_path
    return admin_webhook_endpoints_path if @return_delivery_status == "all"

    admin_webhook_endpoints_path(delivery_status: @return_delivery_status)
  end

  def filtered_index_delivery_scope
    scope = WebhookDelivery.includes(:webhook_endpoint, :notification_event)
    scope = scope.where(webhook_endpoint_id: @delivery_filters[:webhook_endpoint_id]) if @delivery_filters[:webhook_endpoint_id].present?
    scope = scope.where(event_type: @delivery_filters[:event_type]) if @delivery_filters[:event_type].present?
    scope = scope.public_send(@delivery_filters[:status]) if @delivery_filters[:status].present?
    scope = scope.where(response_status: @delivery_filters[:response_status]) if @delivery_filters[:response_status].present?
    scope = apply_error_query_filter(scope)
    scope = apply_created_at_filters(scope)
    scope
  end

  def apply_created_at_filters(scope)
    from_date = parsed_filter_date(@delivery_filters[:created_from])
    to_date = parsed_filter_date(@delivery_filters[:created_to])
    scope = scope.where("webhook_deliveries.created_at >= ?", from_date.beginning_of_day) if from_date
    scope = scope.where("webhook_deliveries.created_at <= ?", to_date.end_of_day) if to_date
    scope
  end

  def apply_error_query_filter(scope)
    return scope if @delivery_filters[:error_q].blank?

    escaped_query = ActiveRecord::Base.sanitize_sql_like(@delivery_filters[:error_q].downcase)
    scope.where("LOWER(webhook_deliveries.error_message) LIKE ?", "%#{escaped_query}%")
  end

  def delivery_search_filter_params
    permitted = params.permit(:webhook_endpoint_id, :event_type, :status, :created_from, :created_to, :response_status, :error_q).to_h.symbolize_keys
    filters = {}

    endpoint_id = permitted[:webhook_endpoint_id].to_s
    filters[:webhook_endpoint_id] = endpoint_id if endpoint_id.match?(/\A\d+\z/)

    event_type = permitted[:event_type].to_s
    filters[:event_type] = event_type if WebhookEndpoint::EVENT_TYPES.include?(event_type)

    status = permitted[:status].to_s
    filters[:status] = status if DELIVERY_STATUS_FILTERS.include?(status)

    response_status = permitted[:response_status].to_s
    if response_status.match?(/\A\d+\z/) && response_status.to_i.between?(100, 599)
      filters[:response_status] = response_status
    end

    error_q = normalized_error_query(permitted[:error_q])
    filters[:error_q] = error_q if error_q.present?

    created_from = permitted[:created_from].to_s
    filters[:created_from] = created_from if parsed_filter_date(created_from)

    created_to = permitted[:created_to].to_s
    filters[:created_to] = created_to if parsed_filter_date(created_to)

    filters
  end

  def selected_webhook_endpoint_for_filter
    return if @delivery_filters[:webhook_endpoint_id].blank?

    WebhookEndpoint.find_by(id: @delivery_filters[:webhook_endpoint_id])
  end

  def searchable_webhook_endpoints
    scope = WebhookEndpoint.order(:name, :id)
    query = normalize_webhook_endpoint_search_query(params[:q])
    return scope.limit(WEBHOOK_ENDPOINT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{WebhookEndpoint.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(webhook_endpoints.name) LIKE :pattern OR LOWER(webhook_endpoints.target_url) LIKE :pattern",
      pattern:
    ).limit(WEBHOOK_ENDPOINT_SEARCH_LIMIT)
  end

  def normalize_webhook_endpoint_search_query(value)
    value.to_s.strip.first(WEBHOOK_ENDPOINT_SEARCH_QUERY_MAX_LENGTH)
  end

  def webhook_endpoint_options(endpoints)
    endpoints.map { |endpoint| webhook_endpoint_option(endpoint) }
  end

  def webhook_endpoint_option(endpoint)
    { value: endpoint.id, text: helpers.webhook_delivery_endpoint_option_label(endpoint) }
  end

  def normalized_error_query(value)
    value.to_s.strip.first(ERROR_QUERY_MAX_LENGTH)
  end

  def delivery_history_page_param
    requested_page = params[:page].to_i
    requested_page.positive? ? requested_page : 1
  end

  def delivery_index_return_params(filters, page)
    filters.merge(return_context: "deliveries_index", page: page > 1 ? page : nil).compact
  end

  def delivery_filter_warnings
    invalid_delivery_date_filter_values.map do |key, _value|
      "#{DATE_FILTER_LABELS.fetch(key)}の値が日付として解釈できないため、この条件は適用していません。"
    end
  end

  def invalid_delivery_date_filter_values
    permitted = params.permit(:created_from, :created_to).to_h.symbolize_keys

    DATE_FILTER_LABELS.keys.each_with_object({}) do |key, invalid_values|
      value = permitted[key].to_s
      invalid_values[key] = value if value.present? && parsed_filter_date(value).nil?
    end
  end

  def parsed_filter_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def current_failed_delivery_scope
    WebhookDelivery.includes(:webhook_endpoint, :notification_event).failed.recent.limit(FAILED_DELIVERY_RETRY_LIMIT)
  end

  def failure_handoff_note(entries)
    if entries.empty?
      "現在条件で Webhook 継続失敗 handoff 対象はありません。Webhook 全体正常、外部監視 green、通知不要を意味しません。"
    else
      "Webhook 継続失敗候補の read-only handoff です。通知・ack・自動 retry・再通知抑制は実行しません。"
    end
  end
end
