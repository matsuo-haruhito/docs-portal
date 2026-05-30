class Admin::WebhookEndpointsController < Admin::BaseController
  DELIVERY_STATUS_FILTERS = %w[failed pending succeeded].freeze
  RECENT_DELIVERY_DISPLAY_LIMIT = 50

  before_action :require_admin_only!
  before_action :set_webhook_endpoint, only: %i[edit update destroy]

  def index
    @webhook_endpoints = WebhookEndpoint.order(:name)
    @webhook_endpoint = WebhookEndpoint.new(active: true, event_types: %w[document_updated document_published])
    @delivery_status_filter = delivery_status_filter
    recent_deliveries_scope = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent
    @recent_delivery_counts = WebhookDelivery.group(:status).count
    @recent_deliveries_any = @recent_delivery_counts.values.sum.positive?
    filtered_deliveries_scope = filtered_delivery_scope(recent_deliveries_scope)
    @recent_deliveries_total_count = filtered_deliveries_scope.count
    @recent_deliveries_limit = RECENT_DELIVERY_DISPLAY_LIMIT
    @recent_deliveries = filtered_deliveries_scope.limit(@recent_deliveries_limit)
  end

  def create
    @webhook_endpoint = WebhookEndpoint.new(webhook_endpoint_params)

    if @webhook_endpoint.save
      redirect_to admin_webhook_endpoints_path, notice: "Webhook設定を登録しました。"
    else
      @webhook_endpoints = WebhookEndpoint.order(:name)
      @delivery_status_filter = "all"
      recent_deliveries_scope = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent
      @recent_delivery_counts = WebhookDelivery.group(:status).count
      @recent_deliveries_any = @recent_delivery_counts.values.sum.positive?
      @recent_deliveries_total_count = recent_deliveries_scope.count
      @recent_deliveries_limit = RECENT_DELIVERY_DISPLAY_LIMIT
      @recent_deliveries = recent_deliveries_scope.limit(@recent_deliveries_limit)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @webhook_endpoint.update(webhook_endpoint_params)
      redirect_to admin_webhook_endpoints_path, notice: "Webhook設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @webhook_endpoint.destroy!
    redirect_to admin_webhook_endpoints_path, notice: "Webhook設定を削除しました。"
  end

  private

  def set_webhook_endpoint
    @webhook_endpoint = WebhookEndpoint.find_by!(public_id: params[:public_id])
  end

  def webhook_endpoint_params
    permitted = params.require(:webhook_endpoint).permit(:name, :target_url, :secret_token, :active, event_types: [])
    permitted[:event_types] = Array(permitted[:event_types]).reject(&:blank?)
    permitted
  end

  def delivery_status_filter
    filter = params[:delivery_status].to_s
    DELIVERY_STATUS_FILTERS.include?(filter) ? filter : "all"
  end

  def filtered_delivery_scope(scope)
    return scope if @delivery_status_filter == "all"

    scope.public_send(@delivery_status_filter)
  end
end
