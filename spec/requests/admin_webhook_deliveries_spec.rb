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

  def endpoint_filter
    parsed_html.at_css(%(input[name="webhook_endpoint_id"])) || parsed_html.at_css(%(select[name="webhook_endpoint_id"]))
  end

  def selected_value(node)
    node&.[]("value").presence || node&.at_css("option[selected]")&.[]("value")
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

  it "drops unsupported event and status filters while normalizing error query return params" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(:webhook_endpoint, name: "Normalized Filter Hook")
    normalized_query = "x" * Admin::WebhookDeliveriesController::ERROR_QUERY_MAX_LENGTH
    long_query = "  #{normalized_query}ignored-suffix  "
    matching_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "prefix #{normalized_query} suffix",
      created_at: Time.zone.local(2026, 6, 10, 10, 0, 0)
    )
    other_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "prefix #{'x' * 99}y suffix",
      created_at: Time.zone.local(2026, 6, 10, 9, 0, 0)
    )

    get admin_webhook_deliveries_path(
      event_type: "unknown_event",
      status: "archived",
      error_q: long_query
    )

    expect(response).to have_http_status(:ok)
    expect(input_value("error_q")).to eq(normalized_query)
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        error_q: normalized_query,
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        event_type: "unknown_event",
        status: "archived",
        error_q: normalized_query,
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        other_delivery.public_id,
        error_q: normalized_query,
        return_context: "deliveries_index"
      )
    )
  end

  it "renders the webhook endpoint filter as bounded remote search with selected values" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Selected Hook", target_url: "https://hooks.example.com/selected")
    event = create(:notification_event, event_type: :document_updated)
    create_delivery(endpoint: endpoint, event: event, status: :failed, created_at: Time.zone.local(2026, 6, 10, 10, 0, 0))

    get admin_webhook_deliveries_path(webhook_endpoint_id: endpoint.id)

    expect(response).to have_http_status(:ok)
    expect(endpoint_filter).to be_present
    expect(selected_value(endpoint_filter)).to eq(endpoint.id.to_s)
    expect(response.body).to include("設定名・送信先URLで検索")
    expect(page_text).to include("設定名または送信先URLの一部で検索できます。候補は最大#{Admin::WebhookDeliveriesController::WEBHOOK_ENDPOINT_SEARCH_LIMIT}件まで表示され")
    expect(page_text).to include("選択済みの設定は候補上限外でも復元されます。")
    expect(response.body).to include(webhook_endpoint_search_admin_webhook_deliveries_path(format: :json))
    expect(response.body).to include(selected_webhook_endpoint_admin_webhook_deliveries_path(format: :json))
  end

  it "returns bounded remote endpoint search options and selected endpoint labels" do
    sign_in_as(admin_user)

    matching_endpoint = create(:webhook_endpoint, name: "Audit Hook", target_url: "https://hooks.example.com/audit")
    create(:webhook_endpoint, name: "Billing Hook", target_url: "https://hooks.example.com/billing")

    get webhook_endpoint_search_admin_webhook_deliveries_path(format: :json), params: { q: "audit" }

    expect(response).to have_http_status(:ok)
    endpoint_options = JSON.parse(response.body).fetch("options")
    expect(endpoint_options).to contain_exactly(
      include("value" => matching_endpoint.id, "text" => "Audit Hook / https://hooks.example.com/audit")
    )

    get selected_webhook_endpoint_admin_webhook_deliveries_path(format: :json), params: { id: matching_endpoint.id }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("option")).to include(
      "value" => matching_endpoint.id,
      "text" => "Audit Hook / https://hooks.example.com/audit"
    )
  end

  it "bounds remote endpoint search result counts" do
    sign_in_as(admin_user)

    22.times do |index|
      create(
        :webhook_endpoint,
        name: "Searchable Hook #{index}",
        target_url: "https://hooks.example.com/searchable/#{index}"
      )
    end

    get webhook_endpoint_search_admin_webhook_deliveries_path(format: :json), params: { q: "Searchable Hook" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("options").size).to eq(Admin::WebhookDeliveriesController::WEBHOOK_ENDPOINT_SEARCH_LIMIT)
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
    old_failed_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "old timeout",
      created_at: Time.zone.local(2026, 6, 9, 9, 0, 0)
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

    get admin_webhook_deliveries_path(
      status: "failed",
      error_q: "timeout",
      created_from: "2026-06-10",
      created_to: "not-a-date"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("作成日Toの値が日付として解釈できないため、この条件は適用していません。")
    expect(input_value("created_to")).to eq("not-a-date")
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_from: "2026-06-10",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        future_failed_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_from: "2026-06-10",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        succeeded_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_from: "2026-06-10",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(
        old_failed_delivery.public_id,
        status: "failed",
        error_q: "timeout",
        created_from: "2026-06-10",
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
    expect(selected_value(endpoint_filter)).to eq(endpoint.id.to_s)
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
    expect(selected_value(endpoint_filter)).to eq(endpoint.id.to_s)
    expect(action_targets).to include(admin_webhook_deliveries_path(filters.merge(page: 1)))
    expect(action_targets).to include(
      admin_webhook_delivery_path(deliveries.last.public_id, filters.merge(return_context: "deliveries_index", page: 2))
    )
    expect(action_targets).not_to include(
      admin_webhook_delivery_path(deliveries.first.public_id, filters.merge(return_context: "deliveries_index", page: 2))
    )
  end

  it "masks diagnostic values on the delivery detail page" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(
      :webhook_endpoint,
      name: "Masked Hook",
      target_url: "https://hooks.example.test/webhooks/docs-portal?secret=query-secret-token&token=query-token"
    )
    response_tail = "tail-token-should-not-appear"
    response_body = [
      "authorization: Bearer response-token",
      "email=response-user@example.test",
      "path=/Users/alice/private/report.pdf",
      ("safe diagnostic body " * 40),
      response_tail
    ].join("\n")
    delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      error_message: "Authorization: Bearer error-token token=error-token email=owner@example.test path=/home/alice/secret.txt",
      response_body: response_body,
      created_at: Time.zone.local(2026, 6, 10, 10, 0, 0)
    )

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("https://hooks.example.test/webhooks/docs-portal?...")
    expect(page_text).to include("Authorization: [masked]")
    expect(page_text).to include("authorization: [masked]")
    expect(page_text).to include("[path hidden]")
    expect(page_text).to include("...省略...")

    aggregate_failures do
      expect(response.body).not_to include("query-secret-token")
      expect(response.body).not_to include("query-token")
      expect(response.body).not_to include("Bearer error-token")
      expect(response.body).not_to include("Bearer response-token")
      expect(response.body).not_to include("error-token")
      expect(response.body).not_to include("response-token")
      expect(response.body).not_to include("owner@example.test")
      expect(response.body).not_to include("response-user@example.test")
      expect(response.body).not_to include("/home/alice/secret.txt")
      expect(response.body).not_to include("/Users/alice/private/report.pdf")
      expect(response.body).not_to include(response_tail)
    end
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
      webhook_endpoint_id: endpoint.id.to_s,
      event_type: "document_updated",
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
