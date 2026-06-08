require "rails_helper"
require "uri"

RSpec.describe "Admin webhook delivery search", type: :request do
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

  def delivery_endpoint_names
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='endpoint']").map { |node| node.text.squish }
  end

  def delivery_status_labels
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='status']").map { |node| node.text.squish }
  end

  it "filters deliveries by endpoint, event type, status, and created date range" do
    sign_in_as(admin_user)

    target_endpoint = create(:webhook_endpoint, name: "Target Hook", event_types: %w[document_updated qa_answered])
    other_endpoint = create(:webhook_endpoint, name: "Other Hook", event_types: %w[document_updated])
    target_event = create(:notification_event, event_type: :qa_answered)
    other_event = create(:notification_event, event_type: :document_updated)
    matched = create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :failed,
      error_message: "timeout",
      created_at: Time.zone.local(2026, 5, 3, 10, 0, 0)
    )
    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: other_event,
      event_type: "document_updated",
      status: :failed,
      created_at: Time.zone.local(2026, 5, 3, 11, 0, 0)
    )
    create(
      :webhook_delivery,
      webhook_endpoint: other_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :failed,
      created_at: Time.zone.local(2026, 5, 3, 12, 0, 0)
    )
    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :succeeded,
      created_at: Time.zone.local(2026, 5, 3, 13, 0, 0)
    )
    create(
      :webhook_delivery,
      webhook_endpoint: target_endpoint,
      notification_event: target_event,
      event_type: "qa_answered",
      status: :failed,
      created_at: Time.zone.local(2026, 4, 30, 10, 0, 0)
    )

    get admin_webhook_deliveries_path(
      webhook_endpoint_id: target_endpoint.id,
      event_type: "qa_answered",
      status: "failed",
      created_from: "2026-05-01",
      created_to: "2026-05-04"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Webhook送信履歴検索")
    expect(page_text).to include("表示範囲: 1件中1件")
    expect(page_text).to include("Target Hook")
    expect(page_text).to include("Q&A回答")
    expect(page_text).to include("失敗")
    expect(page_text).to include("timeout")
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matched.public_id,
        return_context: "deliveries_index",
        webhook_endpoint_id: target_endpoint.id.to_s,
        event_type: "qa_answered",
        status: "failed",
        created_from: "2026-05-01",
        created_to: "2026-05-04"
      )
    )
    expect(delivery_endpoint_names).to eq(["Target Hook"])
    expect(delivery_status_labels).to eq(["失敗"])
  end

  it "shows invalid created date warnings while preserving valid filters" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Error Hook", event_types: %w[document_updated])
    event = create(:notification_event, event_type: :document_updated)
    matched = create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "timeout while sending",
      created_at: Time.zone.local(2026, 6, 2, 10, 0, 0)
    )
    create(
      :webhook_delivery,
      webhook_endpoint: create(:webhook_endpoint, name: "Success Hook", event_types: %w[document_updated]),
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded,
      response_status: 200,
      error_message: "timeout while sending",
      created_at: Time.zone.local(2026, 6, 2, 11, 0, 0)
    )

    get admin_webhook_deliveries_path(
      created_from: "not-a-date",
      created_to: "2026-06-30",
      status: "failed",
      response_status: "500",
      error_q: "timeout"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("作成日Fromの値が日付として解釈できないため、この条件は適用していません。")
    expect(page_text).to include("Error Hook")
    expect(page_text).to include("timeout while sending")
    expect(page_text).to include("500")
    expect(page_text).not_to include("Success Hook")
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matched.public_id,
        return_context: "deliveries_index",
        status: "failed",
        response_status: "500",
        error_q: "timeout",
        created_to: "2026-06-30"
      )
    )
  end

  it "shows unfiltered deliveries newest first with a bounded result list" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Bounded Hook")
    event = create(:notification_event, event_type: :document_updated)
    base_time = Time.zone.local(2026, 5, 1, 0, 0, 0)

    101.times do |index|
      create(
        :webhook_delivery,
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: "document_updated",
        status: :failed,
        error_message: "failure-#{index}",
        created_at: base_time + index.minutes
      )
    end

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 101件中100件")
    expect(page_text).to include("さらに古い履歴を探す場合は")
    expect(page_text).to include("failure-100")
    expect(page_text).to include("failure-1")
    expect(page_text).not_to include("failure-0")
    expect(action_targets).not_to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))
  end

  it "returns safely from detail and single retry to the filtered delivery index" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Retry Hook", active: true)
    event = create(:notification_event, event_type: :document_updated)
    delivery = create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      created_at: Time.zone.local(2026, 5, 3, 10, 0, 0)
    )
    dispatcher = instance_double(WebhookDeliveryDispatcher)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |redelivered_delivery|
      create(:webhook_delivery, webhook_endpoint: redelivered_delivery.webhook_endpoint, notification_event: redelivered_delivery.notification_event, status: :succeeded)
    end

    return_params = {
      return_context: "deliveries_index",
      webhook_endpoint_id: endpoint.id.to_s,
      event_type: "document_updated",
      status: "failed",
      created_from: "2026-05-01",
      created_to: "2026-05-04"
    }
    detail_path = admin_webhook_delivery_path(delivery.public_id, return_params)
    retry_path = retry_dispatch_admin_webhook_delivery_path(delivery.public_id, return_params)
    index_path = admin_webhook_deliveries_path(return_params.except(:return_context))

    get detail_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("送信履歴検索へ戻る")
    expect(action_targets).to include(index_path)
    expect(action_targets).to include(retry_path)

    expect do
      post retry_path
    end.to change(WebhookDelivery, :count).by(1)

    expect(dispatcher).to have_received(:redeliver!).with(delivery)
    expect(response).to redirect_to(index_path)
  end

  it "ignores unsafe return context values instead of redirecting to arbitrary URLs" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :failed)

    get admin_webhook_delivery_path(delivery.public_id, return_context: "https://evil.example.test", status: "failed")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_endpoints_path)
    expect(action_targets).not_to include("https://evil.example.test")
  end
end
