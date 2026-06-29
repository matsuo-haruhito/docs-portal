require "rails_helper"

RSpec.describe "Admin webhook delivery failure handoff", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def json_response
    JSON.parse(response.body)
  end

  def create_delivery(endpoint:, event:, created_at:, **attributes)
    create(
      :webhook_delivery,
      {
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: event.event_type,
        target_url: endpoint.target_url,
        created_at: created_at
      }.merge(attributes)
    )
  end

  it "returns bounded read-only handoff candidates for latest consecutive failures" do
    endpoint = create(
      :webhook_endpoint,
      name: "Operations Hook",
      target_url: "https://hooks.example.test/webhooks/docs?token=raw-query-token"
    )
    event = create(:notification_event, event_type: :document_updated)
    base_time = Time.zone.local(2026, 6, 28, 12, 0, 0)
    3.times do |index|
      create_delivery(
        endpoint: endpoint,
        event: event,
        status: :failed,
        response_status: 500,
        error_message: "Authorization: Bearer secret-token token=secret-token path=/home/alice/private.txt timeout #{index}",
        sent_at: base_time - index.minutes,
        created_at: base_time - index.minutes
      )
    end
    create_delivery(
      endpoint: endpoint,
      event: event,
      status: :succeeded,
      response_status: 204,
      error_message: "older success should end the failed streak",
      sent_at: base_time - 10.minutes,
      created_at: base_time - 10.minutes
    )

    recovered_endpoint = create(:webhook_endpoint, name: "Recovered Hook")
    recovered_event = create(:notification_event, event_type: :document_updated)
    create_delivery(endpoint: recovered_endpoint, event: recovered_event, status: :succeeded, created_at: base_time + 1.minute)
    3.times do |index|
      create_delivery(
        endpoint: recovered_endpoint,
        event: recovered_event,
        status: :failed,
        response_status: 500,
        error_message: "old recovered failure #{index}",
        created_at: base_time - (20 + index).minutes
      )
    end

    sign_in_as(admin_user)

    expect do
      get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)
    end.not_to change(WebhookDelivery, :count)

    expect(response).to have_http_status(:ok)
    payload = json_response
    candidate = payload.fetch("candidates").sole

    expect(payload.fetch("current_filter")).to include(
      "threshold" => Admin::WebhookDeliveriesController::FAILURE_HANDOFF_THRESHOLD,
      "lookback_limit" => Admin::WebhookDeliveriesController::FAILURE_HANDOFF_LOOKBACK_LIMIT
    )
    expect(payload.fetch("total_count")).to eq(1)
    expect(payload.fetch("limit")).to eq(Admin::WebhookDeliveriesController::FAILURE_HANDOFF_LIMIT)
    expect(payload.fetch("truncated")).to be(false)
    expect(payload.fetch("note")).to include("read-only handoff")
    expect(payload.fetch("note")).to include("自動 retry")
    expect(payload.fetch("runbook_path")).to eq(WebhookDeliveries::FailureAlertHandoff::RUNBOOK_PATH)

    expect(candidate).to include(
      "endpoint_name" => "Operations Hook",
      "endpoint_active" => true,
      "event_type" => "document_updated",
      "target_url_preview" => "https://hooks.example.test/webhooks/docs?...",
      "response_status" => 500,
      "failure_count" => 3,
      "failed_deliveries_path" => admin_webhook_deliveries_path(
        webhook_endpoint_id: endpoint.id,
        event_type: "document_updated",
        status: "failed",
        response_status: 500
      ),
      "runbook_path" => WebhookDeliveries::FailureAlertHandoff::RUNBOOK_PATH
    )
    expect(candidate.fetch("identity")).to include(
      "webhook_endpoint_id" => endpoint.id,
      "event_type" => "document_updated",
      "target_url_preview" => "https://hooks.example.test/webhooks/docs?..."
    )
    expect(candidate.fetch("latest_error_message")).to include("Authorization: Bearer [FILTERED]")
    expect(candidate.fetch("latest_error_message")).to include("token=[FILTERED]")
    expect(candidate.fetch("latest_error_message")).to include("[path omitted]")

    aggregate_failures do
      expect(payload.to_s).not_to include("raw-query-token")
      expect(payload.to_s).not_to include("secret-token")
      expect(payload.to_s).not_to include("/home/alice/private.txt")
      expect(payload.to_s).not_to include("Recovered Hook")
    end
  end

  it "keeps stopped endpoints as read-only investigation candidates without retry meaning" do
    endpoint = create(:webhook_endpoint, name: "Stopped Hook", active: false)
    event = create(:notification_event, event_type: :import_failed)
    3.times do |index|
      create_delivery(
        endpoint: endpoint,
        event: event,
        status: :failed,
        response_status: 503,
        error_message: "stopped endpoint failure #{index}",
        created_at: Time.zone.local(2026, 6, 28, 11, index, 0)
      )
    end

    sign_in_as(admin_user)
    get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)

    expect(response).to have_http_status(:ok)
    candidate = json_response.fetch("candidates").sole
    expect(candidate).to include(
      "endpoint_name" => "Stopped Hook",
      "endpoint_active" => false,
      "failure_count" => 3
    )
    expect(json_response.fetch("note")).to include("自動 retry")
  end

  it "bounds candidates and reports truncation" do
    base_time = Time.zone.local(2026, 6, 28, 10, 0, 0)
    21.times do |candidate_index|
      endpoint = create(:webhook_endpoint, name: "Candidate Hook #{candidate_index}")
      event = create(:notification_event, event_type: :document_updated)
      3.times do |failure_index|
        create_delivery(
          endpoint: endpoint,
          event: event,
          status: :failed,
          response_status: 500,
          error_message: "candidate #{candidate_index} failure #{failure_index}",
          created_at: base_time - candidate_index.minutes - failure_index.seconds
        )
      end
    end

    sign_in_as(admin_user)
    get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)

    expect(response).to have_http_status(:ok)
    payload = json_response
    expect(payload.fetch("total_count")).to eq(Admin::WebhookDeliveriesController::FAILURE_HANDOFF_LIMIT + 1)
    expect(payload.fetch("limit")).to eq(Admin::WebhookDeliveriesController::FAILURE_HANDOFF_LIMIT)
    expect(payload.fetch("truncated")).to be(true)
    expect(payload.fetch("candidates").size).to eq(Admin::WebhookDeliveriesController::FAILURE_HANDOFF_LIMIT)
  end

  it "returns an explicit zero-candidate note without implying all clear" do
    sign_in_as(admin_user)

    get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)

    expect(response).to have_http_status(:ok)
    payload = json_response
    expect(payload.fetch("total_count")).to eq(0)
    expect(payload.fetch("candidates")).to eq([])
    expect(payload.fetch("truncated")).to be(false)
    expect(payload.fetch("note")).to include("Webhook 全体正常")
    expect(payload.fetch("note")).to include("意味しません")
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)

    expect(response).to have_http_status(:forbidden)
  end
end
