class Admin::WebhookDeliveriesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_webhook_delivery, only: :retry_dispatch

  def retry_dispatch
    unless @webhook_delivery.failed?
      redirect_to admin_webhook_endpoints_path, alert: "失敗していないWebhook送信履歴は再送できません。"
      return
    end

    unless @webhook_delivery.webhook_endpoint.active?
      redirect_to admin_webhook_endpoints_path, alert: "停止中のWebhook設定には再送できません。"
      return
    end

    WebhookDeliveryDispatcher.new.redeliver!(@webhook_delivery)
    redirect_to admin_webhook_endpoints_path, notice: "Webhookを再送しました。結果は送信履歴で確認してください。"
  end

  private

  def set_webhook_delivery
    @webhook_delivery = WebhookDelivery.includes(:webhook_endpoint, :notification_event).find_by!(public_id: params[:public_id])
  end
end
