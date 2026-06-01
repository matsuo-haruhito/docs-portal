class Admin::WebhookDeliveriesController < Admin::BaseController
  INDEX_DELIVERY_DISPLAY_LIMIT = 100
  FAILED_DELIVERY_RETRY_LIMIT = Admin::WebhookEndpointsController::RECENT_DELIVERY_DISPLAY_LIMIT
  DELIVERY_STATUS_FILTERS = Admin::WebhookEndpointsController::DELIVERY_STATUS_FILTERS
  RETURN_DELIVERY_STATUS_FILTERS = (["all"] + DELIVERY_STATUS_FILTERS).freeze

  before_action :require_admin_only!
  before_action :set_webhook_delivery, only: %i[show retry_dispatch]
  before_action :set_return_delivery_target, only: %i[show retry_dispatch]

  def index
    @filters = delivery_index_filters
    @webhook_endpoints = WebhookEndpoint.order(:name)
    @event_type_options = NotificationEvent.event_types.keys
    filtered_deliveries = filtered_delivery_index_scope
    @webhook_deliveries_total_count = filtered_deliveries.count
    @webhook_deliveries_limit = INDEX_DELIVERY_DISPLAY_LIMIT
    @webhook_deliveries = filtered_deliveries.limit(@webhook_deliveries_limit)
  end

  def show
  end

  def retry_dispatch
    unless @webhook_delivery.failed?
      redirect_to webhook_delivery_return_path, alert: "失敗していないWebhook送信履歴は再送できません。"
      return
    end

    unless @webhook_delivery.webhook_endpoint.active?
      redirect_to webhook_delivery_return_path, alert: "停止中のWebhook設定には再送できません。"
      return
    end

    WebhookDeliveryDispatcher.new.redeliver!(@webhook_delivery)
    redirect_to webhook_delivery_return_path, notice: "Webhookを再送しました。結果は送信履歴で確認してください。"
  end

  def retry_failed
    unless params[:delivery_status].to_s == "failed"
      redirect_to admin_webhook_endpoints_path, alert: "まとめて再送は失敗のみ表示から実行してください。"
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

  private

  def set_webhook_delivery
    @webhook_delivery = WebhookDelivery.includes(:webhook_endpoint, :notification_event).find_by!(public_id: params[:public_id])
  end

  def set_return_delivery_target
    @return_to = safe_delivery_return_to(params[:return_to])
    return if @return_to.present?

    requested_status = params[:return_delivery_status].to_s
    @return_delivery_status = RETURN_DELIVERY_STATUS_FILTERS.include?(requested_status) ? requested_status : "all"
  end

  def webhook_delivery_return_path
    return @return_to if @return_to.present?
    return admin_webhook_endpoints_path if @return_delivery_status == "all"

    admin_webhook_endpoints_path(delivery_status: @return_delivery_status)
  end

  def safe_delivery_return_to(value)
    path = value.to_s
    return if path.blank?

    index_path = admin_webhook_deliveries_path
    return path if path == index_path || path.start_with?("#{index_path}?")

    nil
  end

  def current_failed_delivery_scope
    WebhookDelivery.includes(:webhook_endpoint, :notification_event).failed.recent.limit(FAILED_DELIVERY_RETRY_LIMIT)
  end

  def filtered_delivery_index_scope
    scope = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent
    scope = scope.where(webhook_endpoint_id: selected_webhook_endpoint.id) if selected_webhook_endpoint
    scope = scope.where(event_type: @filters[:event_type]) if @filters[:event_type].present?
    scope = scope.where(status: @filters[:status]) if @filters[:status].present?
    scope = apply_created_at_filters(scope)
    scope
  end

  def apply_created_at_filters(scope)
    created_from = parse_filter_date(@filters[:created_from])
    created_to = parse_filter_date(@filters[:created_to])

    scope = scope.where("webhook_deliveries.created_at >= ?", created_from.beginning_of_day) if created_from
    scope = scope.where("webhook_deliveries.created_at <= ?", created_to.end_of_day) if created_to
    scope
  end

  def parse_filter_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def selected_webhook_endpoint
    return if @filters[:endpoint_id].blank?

    @selected_webhook_endpoint ||= WebhookEndpoint.find_by(public_id: @filters[:endpoint_id])
  end

  def delivery_index_filters
    permitted = params.permit(:endpoint_id, :event_type, :status, :created_from, :created_to)
    permitted[:endpoint_id] = nil if permitted[:endpoint_id].present? && WebhookEndpoint.where(public_id: permitted[:endpoint_id]).none?
    permitted[:event_type] = nil if permitted[:event_type].present? && NotificationEvent.event_types.exclude?(permitted[:event_type])
    permitted[:status] = nil if permitted[:status].present? && DELIVERY_STATUS_FILTERS.exclude?(permitted[:status])
    permitted
  end
end
