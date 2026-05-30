class Admin::WebhookDeliveriesController < Admin::BaseController
  FAILED_DELIVERY_RETRY_LIMIT = Admin::WebhookEndpointsController::RECENT_DELIVERY_DISPLAY_LIMIT

  before_action :require_admin_only!
  before_action :set_webhook_delivery, only: %i[show retry_dispatch]

  def show
  end

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

  def current_failed_delivery_scope
    WebhookDelivery.includes(:webhook_endpoint, :notification_event).failed.recent.limit(FAILED_DELIVERY_RETRY_LIMIT)
  end
end
