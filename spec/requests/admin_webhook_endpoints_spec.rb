require "rails_helper"

RSpec.describe "Admin webhook endpoints", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def delivery_response_status_values
    parsed_html.css("td[data-rails-table-preferences-column-key='response_status']").map { |node| node.text.squish }
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  it "renders localized event labels in the form, endpoint list, and recent deliveries" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      name: "Docs Hook",
      event_types: %w[document_updated qa_answered],
      active: true
    )
    event = create(:notification_event, event_type: :qa_answered)
    create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, event_type: "qa_answered", status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書更新")
    expect(page_text).to include("Q&A回答")
    expect(page_text).to include("失敗")
    expect(page_text).not_to include("document_updated")
    expect(page_text).not_to include("qa_answered")
  end

  it "highlights failed deliveries and filters the recent delivery table by status" do
    sign_in_as(admin_user)

    failed_endpoint = create(:webhook_endpoint, name: "Failed Hook", event_types: %w[document_updated])
    succeeded_endpoint = create(:webhook_endpoint, name: "Success Hook", event_types: %w[document_updated])
    event = create(:notification_event, event_type: :document_updated)
    create(
      :webhook_delivery,
      webhook_endpoint: failed_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "timeout"
    )
    create(
      :webhook_delivery,
      webhook_endpoint: succeeded_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded,
      response_status: 200
    )

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("直近の送信履歴に失敗が1件あります")
    expect(page_text).to include("失敗のみ")
    expect(page_text).to include("Failed Hook")
    expect(page_text).to include("Success Hook")
    expect(delivery_response_status_values).to include("200")

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("失敗のみ")
    expect(page_text).to include("Failed Hook")
    expect(page_text).to include("timeout")
    expect(delivery_response_status_values).not_to include("200")
  end

  it "links recent deliveries to the detail page" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_delivery_path(delivery.public_id))
  end

  it "keeps the existing secret when editing with a blank secret field" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      name: "Blank Secret Hook",
      target_url: "https://example.com/webhooks/original",
      secret_token: "stored-secret",
      active: true,
      event_types: %w[document_updated]
    )

    patch admin_webhook_endpoint_path(endpoint.public_id), params: {
      webhook_endpoint: {
        name: "Blank Secret Hook Updated",
        target_url: "https://example.com/webhooks/updated",
        secret_token: "",
        active: "0",
        event_types: ["", "document_published"]
      }
    }

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    endpoint.reload
    expect(endpoint).to have_attributes(
      name: "Blank Secret Hook Updated",
      target_url: "https://example.com/webhooks/updated",
      secret_token: "stored-secret",
      active: false
    )
    expect(endpoint.event_types).to eq(%w[document_published])
  end

  it "updates the secret only when a new secret is submitted" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      secret_token: "stored-secret",
      event_types: %w[document_updated]
    )

    patch admin_webhook_endpoint_path(endpoint.public_id), params: {
      webhook_endpoint: {
        name: endpoint.name,
        target_url: endpoint.target_url,
        secret_token: "rotated-secret",
        active: "1",
        event_types: ["document_updated", ""]
      }
    }

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    endpoint.reload
    expect(endpoint.secret_token).to eq("rotated-secret")
    expect(endpoint.event_types).to eq(%w[document_updated])
  end

  it "rejects unsupported event types without changing the saved endpoint" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      name: "Supported Hook",
      target_url: "https://example.com/webhooks/supported",
      secret_token: "stored-secret",
      active: true,
      event_types: %w[document_updated]
    )

    patch admin_webhook_endpoint_path(endpoint.public_id), params: {
      webhook_endpoint: {
        name: "Unsupported Hook",
        target_url: "https://example.com/webhooks/unsupported",
        secret_token: "rotated-secret",
        active: "0",
        event_types: ["document_updated", "unsupported_event", ""]
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    endpoint.reload
    expect(endpoint).to have_attributes(
      name: "Supported Hook",
      target_url: "https://example.com/webhooks/supported",
      secret_token: "stored-secret",
      active: true
    )
    expect(endpoint.event_types).to eq(%w[document_updated])
  end

  it "normalizes delivery error query before filtering and return links" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    matching_endpoint = create(:webhook_endpoint, name: "Long Error Hook")
    other_endpoint = create(:webhook_endpoint, name: "Other Error Hook")
    succeeded_endpoint = create(:webhook_endpoint, name: "Succeeded Hook")
    normalized_query = "x" * Admin::WebhookDeliveriesController::ERROR_QUERY_MAX_LENGTH
    long_query = "  #{normalized_query}ignored-suffix  "
    matching_delivery = create(
      :webhook_delivery,
      webhook_endpoint: matching_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "prefix #{normalized_query} suffix"
    )
    other_delivery = create(
      :webhook_delivery,
      webhook_endpoint: other_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "prefix #{'x' * 99}y suffix"
    )
    succeeded_delivery = create(
      :webhook_delivery,
      webhook_endpoint: succeeded_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded,
      response_status: 500,
      error_message: "prefix #{normalized_query} suffix"
    )

    get admin_webhook_deliveries_path(status: "failed", response_status: "500", error_q: long_query)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(input[name="error_q"]))["value"]).to eq(normalized_query)
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        status: "failed",
        response_status: "500",
        error_q: normalized_query,
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        other_delivery.public_id,
        status: "failed",
        response_status: "500",
        error_q: normalized_query,
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        succeeded_delivery.public_id,
        status: "failed",
        response_status: "500",
        error_q: normalized_query,
        return_context: "deliveries_index"
      )
    )

    get admin_webhook_deliveries_path(error_q: "   ")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_delivery_path(matching_delivery.public_id, return_context: "deliveries_index"))
    expect(action_targets).to include(admin_webhook_delivery_path(other_delivery.public_id, return_context: "deliveries_index"))
    expect(action_targets).to include(admin_webhook_delivery_path(succeeded_delivery.public_id, return_context: "deliveries_index"))
    expect(parsed_html.at_css(%(input[name="error_q"]))["value"]).to be_nil
  end

  it "preserves the failed delivery filter through detail and row redelivery" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, active: true)
    event = create(:notification_event, event_type: :document_updated)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, status: :failed)
    dispatcher = instance_double(WebhookDeliveryDispatcher)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |redelivered_delivery|
      create(:webhook_delivery, webhook_endpoint: redelivered_delivery.webhook_endpoint, notification_event: redelivered_delivery.notification_event, status: :succeeded)
    end

    get admin_webhook_endpoints_path(delivery_status: "failed")

    detail_path = admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed")
    retry_path = retry_dispatch_admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed")
    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(detail_path)
    expect(action_targets).to include(retry_path)

    get detail_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_endpoints_path(delivery_status: "failed"))
    expect(action_targets).to include(retry_path)

    expect do
      post retry_path
    end.to change(WebhookDelivery, :count).by(1)

    expect(dispatcher).to have_received(:redeliver!).with(delivery)
    expect(response).to redirect_to(admin_webhook_endpoints_path(delivery_status: "failed"))
    follow_redirect!
    expect(page_text).to include("Webhookを再送しました")
  end

  it "falls back to the unfiltered list for invalid delivery return filters" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :failed)

    get admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "https://evil.example.test")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_endpoints_path)
    expect(action_targets).not_to include("https://evil.example.test")
  end

  it "shows manual redelivery only for failed deliveries on active endpoints" do
    sign_in_as(admin_user)

    active_endpoint = create(:webhook_endpoint, active: true)
    inactive_endpoint = create(:webhook_endpoint, active: false)
    event = create(:notification_event, event_type: :document_updated)
    retryable_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :failed)
    succeeded_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :succeeded)
    inactive_delivery = create(:webhook_delivery, webhook_endpoint: inactive_endpoint, status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(retry_dispatch_admin_webhook_delivery_path(retryable_delivery.public_id))
    expect(action_targets).not_to include(retry_dispatch_admin_webhook_delivery_path(succeeded_delivery.public_id))
    expect(action_targets).not_to include(retry_dispatch_admin_webhook_delivery_path(inactive_delivery.public_id))
    expect(page_text).to include("受信先側の重複処理に注意")
  end

  it "shows bulk redelivery only on the failed filter with retryable delivery summary" do
    sign_in_as(admin_user)

    active_endpoint = create(:webhook_endpoint, name: "Active Hook", active: true)
    inactive_endpoint = create(:webhook_endpoint, name: "Stopped Hook", active: false)
    event = create(:notification_event, event_type: :document_updated)
    create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, event_type: "document_updated", status: :failed)
    create(:webhook_delivery, webhook_endpoint: inactive_endpoint, notification_event: event, event_type: "document_updated", status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).not_to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))
    expect(page_text).to include("表示中のまとめて再送対象: 1件")
    expect(page_text).to include("表示範囲: 失敗のみ 2件中2件を表示しています")
    expect(page_text).to include("Active Hook")
    expect(page_text).to include("文書更新")
    expect(page_text).to include("受信先側の重複処理に注意")
  end

  it "keeps bulk redelivery scoped to the recent failed delivery display limit" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    active_endpoint = create(:webhook_endpoint, name: "Recent Active Hook", active: true)
    inactive_endpoint = create(:webhook_endpoint, name: "Recent Stopped Hook", active: false)
    old_endpoint = create(:webhook_endpoint, name: "Old Active Hook", active: true)
    base_time = Time.zone.local(2026, 5, 30, 12, 0, 0)

    create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :succeeded, created_at: base_time + 4.hours)
    create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :pending, created_at: base_time + 3.hours)
    recent_retryable_deliveries = Array.new(49) do |index|
      create(
        :webhook_delivery,
        webhook_endpoint: active_endpoint,
        notification_event: event,
        event_type: "document_updated",
        status: :failed,
        created_at: base_time + index.minutes
      )
    end
    inactive_delivery = create(
      :webhook_delivery,
      webhook_endpoint: inactive_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      created_at: base_time + 2.hours
    )
    old_retryable_delivery = create(
      :webhook_delivery,
      webhook_endpoint: old_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      created_at: base_time - 1.day
    )
    dispatcher = instance_double(WebhookDeliveryDispatcher)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |delivery|
      create(:webhook_delivery, webhook_endpoint: delivery.webhook_endpoint, notification_event: delivery.notification_event, status: :succeeded)
    end

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))
    expect(page_text).to include("表示中のまとめて再送対象: 49件")
    expect(page_text).to include("表示範囲: 失敗のみ 51件中50件を表示しています")
    expect(page_text).to include("Recent Active Hook")
    expect(page_text).to include("Recent Stopped Hook")
    expect(action_targets).not_to include(admin_webhook_delivery_path(old_retryable_delivery.public_id))
    expect(action_targets).not_to include(retry_dispatch_admin_webhook_delivery_path(inactive_delivery.public_id))
    expect(action_targets).not_to include(retry_dispatch_admin_webhook_delivery_path(old_retryable_delivery.public_id))

    expect do
      post retry_failed_admin_webhook_deliveries_path(delivery_status: "failed")
    end.to change(WebhookDelivery, :count).by(49)

    recent_retryable_deliveries.each do |delivery|
      expect(dispatcher).to have_received(:redeliver!).with(delivery)
    end
    expect(dispatcher).to have_received(:redeliver!).exactly(49).times
    expect(dispatcher).not_to have_received(:redeliver!).with(inactive_delivery)
    expect(dispatcher).not_to have_received(:redeliver!).with(old_retryable_delivery)
    expect(response).to redirect_to(admin_webhook_endpoints_path(delivery_status: "failed"))
  end

  it "hides bulk redelivery when the failed filter has no retryable deliveries" do
    sign_in_as(admin_user)

    inactive_endpoint = create(:webhook_endpoint, active: false)
    create(:webhook_delivery, webhook_endpoint: inactive_endpoint, status: :failed)

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(action_targets).not_to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))
    expect(page_text).to include("再送可能なWebhook送信履歴はありません")
  end

  it "shows masked JSON request body preview on delivery detail" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Failure Hook", active: true, target_url: "https://hooks.example.test/docs")
    event = create(:notification_event, event_type: :document_published)
    delivery = create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: "document_published",
      status: :failed,
      target_url: endpoint.target_url,
      request_body: JSON.generate(
        event_type: "document_published",
        document_slug: "installation-guide",
        secret: "do-not-show",
        authorization: "Bearer hidden-token",
        user: {
          email: "customer@example.test",
          name: "Sensitive Name",
          company_id: "company-visible"
        },
        items: [
          {title: "Visible Section", phone: "090-0000-0000"}
        ]
      ),
      response_status: 503,
      response_body: "service unavailable",
      error_message: "upstream timeout",
      sent_at: Time.zone.local(2026, 5, 30, 12, 0, 0)
    )

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Failure Hook")
    expect(page_text).to include("文書公開")
    expect(page_text).to include("失敗")
    expect(page_text).to include("503")
    expect(page_text).to include("service unavailable")
    expect(page_text).to include("upstream timeout")
    expect(page_text).to include("リクエスト本文")
    expect(page_text).to include("マスク済み preview")
    expect(page_text).to include("document_published")
    expect(page_text).to include("installation-guide")
    expect(page_text).to include("company-visible")
    expect(page_text).to include("Visible Section")
    expect(page_text).to include("[masked]")
    expect(page_text).not_to include("first slice では非表示です")
    expect(page_text).not_to include("do-not-show")
    expect(page_text).not_to include("hidden-token")
    expect(page_text).not_to include("customer@example.test")
    expect(page_text).not_to include("Sensitive Name")
    expect(page_text).not_to include("090-0000-0000")
    expect(action_targets).to include(retry_dispatch_admin_webhook_delivery_path(delivery.public_id))
  end

  it "truncates non-JSON request body preview after masking sensitive values" do
    sign_in_as(admin_user)

    delivery = create(
      :webhook_delivery,
      status: :failed,
      request_body: "event_type=document_updated token=non-json-secret note=#{'a' * 800}"
    )

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("event_type=document_updated")
    expect(page_text).to include("token=[masked]")
    expect(page_text).to include("...省略...")
    expect(page_text).not_to include("non-json-secret")
    expect(page_text).not_to include("#{'a' * 700}")
  end

  it "forbids non-admin users from delivery detail" do
    external_user = create(:user, :external)
    delivery = create(:webhook_delivery, status: :failed)

    sign_in_as(external_user)

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:forbidden)
  end

  it "redelivers a failed delivery and keeps the new result in delivery history" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, active: true)
    event = create(:notification_event, event_type: :document_updated)
    failed_delivery = create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, status: :failed)
    dispatcher = instance_double(WebhookDeliveryDispatcher)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |delivery|
      create(:webhook_delivery, webhook_endpoint: delivery.webhook_endpoint, notification_event: delivery.notification_event, status: :succeeded)
    end

    expect do
      post retry_dispatch_admin_webhook_delivery_path(failed_delivery.public_id)
    end.to change(WebhookDelivery, :count).by(1)

    expect(dispatcher).to have_received(:redeliver!).with(failed_delivery)
    expect(response).to redirect_to(admin_webhook_endpoints_path)
    follow_redirect!
    expect(page_text).to include("Webhookを再送しました")
  end

  it "bulk redelivers only failed deliveries on active endpoints" do
    sign_in_as(admin_user)

    active_endpoint = create(:webhook_endpoint, active: true)
    inactive_endpoint = create(:webhook_endpoint, active: false)
    event = create(:notification_event, event_type: :document_updated)
    retryable_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :failed)
    another_retryable_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, status: :failed)
    succeeded_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, status: :succeeded)
    pending_delivery = create(:webhook_delivery, webhook_endpoint: active_endpoint, status: :pending)
    inactive_delivery = create(:webhook_delivery, webhook_endpoint: inactive_endpoint, status: :failed)
    dispatcher = instance_double(WebhookDeliveryDispatcher)

    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:redeliver!) do |delivery|
      create(:webhook_delivery, webhook_endpoint: delivery.webhook_endpoint, notification_event: delivery.notification_event, status: :succeeded)
    end

    expect do
      post retry_failed_admin_webhook_deliveries_path(delivery_status: "failed")
    end.to change(WebhookDelivery, :count).by(2)

    expect(dispatcher).to have_received(:redeliver!).with(retryable_delivery)
    expect(dispatcher).to have_received(:redeliver!).with(another_retryable_delivery)
    expect(dispatcher).not_to have_received(:redeliver!).with(succeeded_delivery)
    expect(dispatcher).not_to have_received(:redeliver!).with(pending_delivery)
    expect(dispatcher).not_to have_received(:redeliver!).with(inactive_delivery)
    expect(response).to redirect_to(admin_webhook_endpoints_path(delivery_status: "failed"))
    follow_redirect!
    expect(page_text).to include("Webhookを2件まとめて再送しました")
  end

  it "rejects bulk redelivery outside the failed filter" do
    sign_in_as(admin_user)

    create(:webhook_delivery, status: :failed)
    allow(WebhookDeliveryDispatcher).to receive(:new)

    expect do
      post retry_failed_admin_webhook_deliveries_path
    end.not_to change(WebhookDelivery, :count)

    expect(WebhookDeliveryDispatcher).not_to have_received(:new)
    expect(response).to redirect_to(admin_webhook_endpoints_path)
    follow_redirect!
    expect(page_text).to include("まとめて再送は失敗のみ表示から実行してください")
  end

  it "rejects redelivery for succeeded deliveries" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :succeeded)
    allow(WebhookDeliveryDispatcher).to receive(:new)

    expect do
      post retry_dispatch_admin_webhook_delivery_path(delivery.public_id)
    end.not_to change(WebhookDelivery, :count)

    expect(WebhookDeliveryDispatcher).not_to have_received(:new)
    expect(response).to redirect_to(admin_webhook_endpoints_path)
    follow_redirect!
    expect(page_text).to include("失敗していないWebhook送信履歴は再送できません")
  end

  it "rejects redelivery for inactive endpoints" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, active: false)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, status: :failed)
    allow(WebhookDeliveryDispatcher).to receive(:new)

    expect do
      post retry_dispatch_admin_webhook_delivery_path(delivery.public_id)
    end.not_to change(WebhookDelivery, :count)

    expect(WebhookDeliveryDispatcher).not_to have_received(:new)
    expect(response).to redirect_to(admin_webhook_endpoints_path)
    follow_redirect!
    expect(page_text).to include("停止中のWebhook設定には再送できません")
  end
end
