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

  it "filters deliveries by endpoint, event type, status, and created date range" do
    sign_in_as(admin_user)

    target_endpoint = create(:webhook_endpoint, name: "Target Hook")
    other_endpoint = create(:webhook_endpoint, name: "Other Hook")
    target_event = create(:notification_event, event_type: :qa_answered)
    other_event = create(:notification_event, event_type: :document_updated)

    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :failed,
      response_status: 503,
      error_message: "target timeout",
      created_at: 2.days.ago
    )
    create(
      :webhook_delivery,
      webhook_endpoint: other_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :failed,
      error_message: "wrong endpoint",
      created_at: 2.days.ago
    )
    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: other_event,
      event_type: "document_updated",
      status: :failed,
      error_message: "wrong event",
      created_at: 2.days.ago
    )
    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :succeeded,
      response_status: 200,
      error_message: "wrong status",
      created_at: 2.days.ago
    )
    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :failed,
      error_message: "too old",
      created_at: 10.days.ago
    )

    get admin_webhook_deliveries_path(
      endpoint_id: target_endpoint.public_id,
      event_type: "qa_answered",
      status: "failed",
      created_from: 3.days.ago.to_date.iso8601,
      created_to: 1.day.ago.to_date.iso8601
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Webhook送信履歴検索")
    expect(page_text).to include("Target Hook")
    expect(page_text).to include("Q&A回答")
    expect(page_text).to include("target timeout")
    expect(page_text).not_to include("wrong endpoint")
    expect(page_text).not_to include("wrong event")
    expect(page_text).not_to include("wrong status")
    expect(page_text).not_to include("too old")
  end

  it "keeps the unfiltered delivery search bounded and ordered by newest first" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Bounded Hook")
    event = create(:notification_event, event_type: :document_updated)
    create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      status: :failed,
      error_message: "outside search limit",
      created_at: 5.days.ago
    )
    101.times do |index|
      create(
        :webhook_delivery,
        webhook_endpoint: endpoint,
        notification_event: event,
        status: :succeeded,
        response_status: 200,
        error_message: "newer delivery #{index}",
        created_at: index.minutes.ago
      )
    end

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する102件中100件")
    expect(page_text).to include("上限外の履歴は条件を追加して絞り込んでください")
    expect(page_text).to include("newer delivery 0")
    expect(page_text).not_to include("outside search limit")
  end

  it "preserves a safe delivery search return path through detail and row redelivery" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, active: true, name: "Retry Hook")
    event = create(:notification_event, event_type: :document_updated)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, status: :failed)
    dispatcher = instance_double(WebhookDeliveryDispatcher)
    return_to = admin_webhook_deliveries_path(status: "failed", event_type: "document_updated")
    detail_path = admin_webhook_delivery_path(delivery.public_id, return_to:)
    retry_path = retry_dispatch_admin_webhook_delivery_path(delivery.public_id, return_to:)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |redelivered_delivery|
      create(:webhook_delivery, webhook_endpoint: redelivered_delivery.webhook_endpoint, notification_event: redelivered_delivery.notification_event, status: :succeeded)
    end

    get admin_webhook_deliveries_path(status: "failed", event_type: "document_updated")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(detail_path)
    expect(action_targets).to include(retry_path)
    expect(action_targets).not_to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))

    get detail_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(return_to)
    expect(action_targets).to include(retry_path)

    expect do
      post retry_path
    end.to change(WebhookDelivery, :count).by(1)

    expect(dispatcher).to have_received(:redeliver!).with(delivery)
    expect(response).to redirect_to(return_to)
    follow_redirect!
    expect(page_text).to include("Webhookを再送しました")
  end

  it "falls back to the endpoint list for unsafe delivery search return paths" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :failed)

    get admin_webhook_delivery_path(delivery.public_id, return_to: "https://evil.example.test/admin/webhook_deliveries")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_endpoints_path)
    expect(action_targets).not_to include("https://evil.example.test/admin/webhook_deliveries")
  end

  it "keeps bulk redelivery limited to the existing failed recent endpoint view" do
    sign_in_as(admin_user)

    active_endpoint = create(:webhook_endpoint, active: true)
    event = create(:notification_event, event_type: :document_updated)
    retryable_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :failed)
    create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :failed, created_at: 2.days.ago)
    dispatcher = instance_double(WebhookDeliveryDispatcher)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |delivery|
      create(:webhook_delivery, webhook_endpoint: delivery.webhook_endpoint, notification_event: delivery.notification_event, status: :succeeded)
    end

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(action_targets).not_to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))

    expect do
      post retry_failed_admin_webhook_deliveries_path(delivery_status: "failed")
    end.to change(WebhookDelivery, :count).by(2)

    expect(dispatcher).to have_received(:redeliver!).with(retryable_delivery)
    expect(response).to redirect_to(admin_webhook_endpoints_path(delivery_status: "failed"))
  end
end
