require "rails_helper"

RSpec.describe "Admin webhook deliveries", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def input_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def create_delivery(endpoint:, event:, created_at:, **attributes)
    create(
      :webhook_delivery,
      {
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: event.event_type,
        created_at: created_at
      }.merge(attributes)
    )
  end

  it "applies only valid HTTP status filter values" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(:webhook_endpoint, name: "Search Hook")
    matching_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "timeout",
      created_at: Time.zone.local(2026, 6, 10, 10, 0, 0)
    )
    other_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 404,
      error_message: "not found",
      created_at: Time.zone.local(2026, 6, 10, 9, 0, 0)
    )

    get admin_webhook_deliveries_path(response_status: "500")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        response_status: "500",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        other_delivery.public_id,
        response_status: "500",
        return_context: "deliveries_index"
      )
    )
    expect(input_value("response_status")).to eq("500")

    %w[99 600 abc].each do |invalid_status|
      get admin_webhook_deliveries_path(response_status: invalid_status)

      expect(response).to have_http_status(:ok)
      expect(action_targets).to include(admin_webhook_delivery_path(matching_delivery.public_id, return_context: "deliveries_index"))
      expect(action_targets).to include(admin_webhook_delivery_path(other_delivery.public_id, return_context: "deliveries_index"))
      expect(action_targets).not_to include(
        admin_webhook_delivery_path(
          matching_delivery.public_id,
          response_status: invalid_status,
          return_context: "deliveries_index"
        )
      )
      expect(input_value("response_status")).to be_nil
    end
  end

  it "shows invalid date warnings without dropping other valid filters" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(:webhook_endpoint, name: "Date Hook")
    matching_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "timeout while posting",
      created_at: Time.zone.local(2026, 6, 10, 10, 0, 0)
    )
    succeeded_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :succeeded,
      response_status: 500,
      error_message: "timeout but succeeded",
      created_at: Time.zone.local(2026, 6, 10, 9, 0, 0)
    )
    future_failed_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "future timeout",
      created_at: Time.zone.local(2026, 6, 11, 9, 0, 0)
    )

    get admin_webhook_deliveries_path(
      status: "failed",
      error_q: "timeout",
      created_from: "not-a-date",
      created_to: "2026-06-10"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("作成日Fromの値が日付として解釈できないため、この条件は適用していません。")
    expect(input_value("created_from")).to eq("not-a-date")
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_to: "2026-06-10",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        succeeded_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_to: "2026-06-10",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        future_failed_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_to: "2026-06-10",
        return_context: "deliveries_index"
      )
    )
  end

  it "shows a result-side reset action only for filtered empty states" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだWebhook送信履歴はありません。")
    expect(page_text).not_to include("すべてのWebhook送信履歴を見る")

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook送信履歴はありません。")
    expect(page_text).to include("すべてのWebhook送信履歴を見る")
    expect(parsed_html.css(%(a[href="#{admin_webhook_deliveries_path}"])).map { |link| link.text.squish }).to include(
      "条件をリセット",
      "すべてのWebhook送信履歴を見る"
    )
  end

  it "keeps filters while paginating and clamps oversized page numbers" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(:webhook_endpoint, name: "Paged Hook")
    base_time = Time.zone.local(2026, 6, 10, 12, 0, 0)
    deliveries = Array.new(101) do |index|
      create_delivery(
        endpoint: endpoint,
        event: event,
        status: :failed,
        response_status: 500,
        error_message: "batch timeout #{index}",
        created_at: base_time - index.minutes
      )
    end
    filters = {
      webhook_endpoint_id: endpoint.id.to_s,
      event_type: "document_updated",
      status: "failed",
      response_status: "500",
      error_q: "batch",
      created_from: "2026-06-10",
      created_to: "2026-06-10"
    }

    get admin_webhook_deliveries_path(filters)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("100件ずつ、1/2ページ")
    expect(action_targets).to include(admin_webhook_deliveries_path(filters.merge(page: 2)))
    expect(action_targets).to include(
      admin_webhook_delivery_path(deliveries.first.public_id, filters.merge(return_context: "deliveries_index"))
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(deliveries.last.public_id, filters.merge(return_context: "deliveries_index"))
    )

    get admin_webhook_deliveries_path(filters.merge(page: 9))

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("100件ずつ、2/2ページ")
    expect(action_targets).to include(admin_webhook_deliveries_path(filters.merge(page: 1)))
    expect(action_targets).to include(
      admin_webhook_delivery_path(deliveries.last.public_id, filters.merge(return_context: "deliveries_index", page: 2))
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(deliveries.first.public_id, filters.merge(return_context: "deliveries_index", page: 2))
    )
  end

  it "preserves delivery search context through detail and redelivery" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Retry Hook", active: true)
    event = create(:notification_event, event_type: :document_updated)
    delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "retry timeout",
      created_at: Time.zone.local(2026, 6, 10, 10, 0, 0)
    )
    dispatcher = instance_double(WebhookDeliveryDispatcher)
    return_filters = {
      status: "failed",
      response_status: "500",
      error_q: "retry",
      created_from: "2026-06-10",
      created_to: "2026-06-10",
      return_context: "deliveries_index",
      page: 2
    }
    detail_path = admin_webhook_delivery_path(delivery.public_id, return_filters)
    retry_path = retry_dispatch_admin_webhook_delivery_path(delivery.public_id, return_filters)
    return_path = admin_webhook_deliveries_path(return_filters.except(:return_context))

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |redelivered_delivery|
      create_delivery(
        endpoint: redelivered_delivery.webhook_endpoint,
        event: redelivered_delivery.notification_event,
        status: :succeeded,
        response_status: 202,
        created_at: Time.zone.local(2026, 6, 10, 10, 1, 0)
      )
    end

    get detail_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(return_path)
    expect(action_targets).to include(retry_path)
    expect(page_text).to include("送信履歴検索へ戻る")

    expect do
      post retry_path
    end.to change(WebhookDelivery, :count).by(1)

    expect(dispatcher).to have_received(:redeliver!).with(delivery)
    expect(response).to redirect_to(return_path)
  end
end
