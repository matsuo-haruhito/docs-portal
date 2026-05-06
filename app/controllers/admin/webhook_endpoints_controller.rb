class Admin::WebhookEndpointsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_webhook_endpoint, only: %i[edit update destroy]

  def index
    @webhook_endpoints = WebhookEndpoint.order(:name)
    @webhook_endpoint = WebhookEndpoint.new(active: true, event_types: %w[document_updated document_published])
    @recent_deliveries = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent.limit(50)
  end

  def create
    @webhook_endpoint = WebhookEndpoint.new(webhook_endpoint_params)

    if @webhook_endpoint.save
      redirect_to admin_webhook_endpoints_path, notice: "Webhook設定を登録しました。"
    else
      @webhook_endpoints = WebhookEndpoint.order(:name)
      @recent_deliveries = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent.limit(50)
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
    @webhook_endpoint = WebhookEndpoint.find_by(id: params[:id]) || WebhookEndpoint.find_by!(public_id: params[:id])
  end

  def webhook_endpoint_params
    permitted = params.require(:webhook_endpoint).permit(:name, :target_url, :secret_token, :active, event_types: [])
    permitted[:event_types] = Array(permitted[:event_types]).reject(&:blank?)
    permitted
  end
end
