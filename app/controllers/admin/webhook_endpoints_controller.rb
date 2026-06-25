class Admin::WebhookEndpointsController < Admin::BaseController
  DELIVERY_STATUS_FILTERS = %w[failed pending succeeded].freeze
  ENDPOINT_ACTIVE_FILTERS = %w[active inactive].freeze
  ENDPOINT_Q_MAX_LENGTH = 100
  ENDPOINT_DEFAULT_PER_PAGE = 25
  ENDPOINT_MAX_PER_PAGE = 50
  RECENT_DELIVERY_DISPLAY_LIMIT = 50

  before_action :require_admin_only!
  before_action :set_webhook_endpoint, only: %i[edit update destroy]

  def index
    @delivery_status_filter = delivery_status_filter
    prepare_webhook_endpoint_list
    @webhook_endpoint = WebhookEndpoint.new(active: true, event_types: %w[document_updated document_published])
    recent_deliveries_scope = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent
    @recent_delivery_counts = WebhookDelivery.group(:status).count
    @recent_deliveries_any = @recent_delivery_counts.values.sum.positive?
    filtered_deliveries_scope = filtered_delivery_scope(recent_deliveries_scope)
    @recent_deliveries_total_count = filtered_deliveries_scope.count
    @recent_deliveries_limit = RECENT_DELIVERY_DISPLAY_LIMIT
    @recent_deliveries = filtered_deliveries_scope.limit(@recent_deliveries_limit)
    @bulk_retryable_deliveries = bulk_retryable_deliveries(@recent_deliveries)
  end

  def create
    @webhook_endpoint = WebhookEndpoint.new(webhook_endpoint_params)

    if @webhook_endpoint.save
      redirect_to admin_webhook_endpoints_path, notice: "Webhook設定を登録しました。"
    else
      @delivery_status_filter = delivery_status_filter
      prepare_webhook_endpoint_list
      recent_deliveries_scope = WebhookDelivery.includes(:webhook_endpoint, :notification_event).recent
      @recent_delivery_counts = WebhookDelivery.group(:status).count
      @recent_deliveries_any = @recent_delivery_counts.values.sum.positive?
      @recent_deliveries_total_count = recent_deliveries_scope.count
      @recent_deliveries_limit = RECENT_DELIVERY_DISPLAY_LIMIT
      @recent_deliveries = recent_deliveries_scope.limit(@recent_deliveries_limit)
      @bulk_retryable_deliveries = []
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
    permitted.delete(:secret_token) if action_name == "update" && permitted[:secret_token].blank?
    permitted
  end

  def prepare_webhook_endpoint_list
    @webhook_endpoint_q = endpoint_q_filter
    @webhook_endpoint_event_filter = endpoint_event_filter
    @webhook_endpoint_active_filter = endpoint_active_filter
    @webhook_endpoints_per_page = endpoint_per_page
    @webhook_endpoint_filters_active = @webhook_endpoint_q.present? || @webhook_endpoint_event_filter != "all" || @webhook_endpoint_active_filter != "all"

    base_scope = WebhookEndpoint.order(:name)
    @webhook_endpoints_any = base_scope.exists?
    filtered_scope = filtered_webhook_endpoint_scope(base_scope)
    @webhook_endpoints_total_count = filtered_scope.count
    @webhook_endpoints_total_pages = [(@webhook_endpoints_total_count.to_f / @webhook_endpoints_per_page).ceil, 1].max
    @webhook_endpoints_page = [endpoint_page, @webhook_endpoints_total_pages].min
    @webhook_endpoint_filter_params = endpoint_filter_params
    @webhook_endpoints = filtered_scope.offset((@webhook_endpoints_page - 1) * @webhook_endpoints_per_page).limit(@webhook_endpoints_per_page)
  end

  def endpoint_q_filter
    params[:endpoint_q].to_s.strip.first(ENDPOINT_Q_MAX_LENGTH)
  end

  def endpoint_event_filter
    filter = params[:endpoint_event].to_s
    WebhookEndpoint::EVENT_TYPES.include?(filter) ? filter : "all"
  end

  def endpoint_active_filter
    filter = params[:endpoint_active].to_s
    ENDPOINT_ACTIVE_FILTERS.include?(filter) ? filter : "all"
  end

  def endpoint_page
    page = params[:endpoint_page].to_i
    page.positive? ? page : 1
  end

  def endpoint_per_page
    per_page = params[:endpoint_per_page].to_i
    per_page = ENDPOINT_DEFAULT_PER_PAGE unless per_page.positive?
    [per_page, ENDPOINT_MAX_PER_PAGE].min
  end

  def filtered_webhook_endpoint_scope(scope)
    scope = filter_webhook_endpoints_by_query(scope)
    scope = scope.where("webhook_endpoints.event_types::jsonb ? :event_type", event_type: @webhook_endpoint_event_filter) if @webhook_endpoint_event_filter != "all"
    scope = scope.where(active: @webhook_endpoint_active_filter == "active") if @webhook_endpoint_active_filter != "all"
    scope
  end

  def filter_webhook_endpoints_by_query(scope)
    return scope if @webhook_endpoint_q.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@webhook_endpoint_q.downcase)}%"
    scope.where(
      "LOWER(webhook_endpoints.name) LIKE :query OR LOWER(webhook_endpoints.target_url) LIKE :query",
      query: pattern
    )
  end

  def endpoint_filter_params
    filter_params = {}
    filter_params[:endpoint_q] = @webhook_endpoint_q if @webhook_endpoint_q.present?
    filter_params[:endpoint_event] = @webhook_endpoint_event_filter if @webhook_endpoint_event_filter != "all"
    filter_params[:endpoint_active] = @webhook_endpoint_active_filter if @webhook_endpoint_active_filter != "all"
    filter_params[:endpoint_per_page] = @webhook_endpoints_per_page if @webhook_endpoints_per_page != ENDPOINT_DEFAULT_PER_PAGE
    filter_params[:delivery_status] = @delivery_status_filter if @delivery_status_filter.present? && @delivery_status_filter != "all"
    filter_params
  end

  def delivery_status_filter
    filter = params[:delivery_status].to_s
    DELIVERY_STATUS_FILTERS.include?(filter) ? filter : "all"
  end

  def filtered_delivery_scope(scope)
    return scope if @delivery_status_filter == "all"

    scope.public_send(@delivery_status_filter)
  end

  def bulk_retryable_deliveries(deliveries)
    return [] unless @delivery_status_filter == "failed"

    deliveries.select(&:retryable?)
  end
end
