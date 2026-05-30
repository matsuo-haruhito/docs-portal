require "rails_helper"

RSpec.describe WebhookDeliveryDispatcher do
  class StubWebhookHttp
    Request = Struct.new(:request)

    attr_reader :requests, :response, :error

    def initialize(response: nil, error: nil)
      @response = response || successful_response
      @error = error
      @requests = []
    end

    def start(host, port, use_ssl:, open_timeout:, read_timeout:)
      http = Struct.new(:client) do
        def request(request)
          client.requests << Request.new(request)
          raise client.error if client.error

          client.response
        end
      end.new(self)

      yield http
    end

    private

    def successful_response
      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        response.instance_variable_set(:@read, true)
        response.instance_variable_set(:@body, "accepted")
      end
    end
  end

  let(:project) { create(:project, code: "WEBHOOK", name: "Webhook Project") }
  let(:document) { create(:document, project:, title: "Webhook対象文書", slug: "webhook-doc") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:event) do
    create(:notification_event,
      event_type: :document_updated,
      project:,
      document:,
      document_version: version,
      title: "Webhook対象文書 が更新されました")
  end

  it "delivers subscribed events with a JSON payload" do
    endpoint = create(:webhook_endpoint, event_types: %w[document_updated])
    create(:webhook_endpoint, event_types: %w[document_published])
    http_client = StubWebhookHttp.new

    deliveries = described_class.new(http_client:).dispatch!(event)

    expect(deliveries.size).to eq(1)
    delivery = deliveries.first
    expect(delivery.error_message).to be_blank
    expect(delivery.webhook_endpoint).to eq(endpoint)
    expect(delivery).to be_succeeded
    expect(delivery.response_status).to eq(200)
    expect(JSON.parse(delivery.request_body)).to include(
      "id" => event.public_id,
      "event_type" => "document_updated",
      "title" => "Webhook対象文書 が更新されました"
    )

    request = http_client.requests.first.request
    expect(request["X-Docs-Portal-Event"]).to eq("document_updated")
  end

  it "records failed delivery history when the request fails" do
    create(:webhook_endpoint, event_types: %w[document_updated])
    http_client = StubWebhookHttp.new(error: StandardError.new("network error"))

    deliveries = described_class.new(http_client:).dispatch!(event)

    expect(deliveries.first).to be_failed
    expect(deliveries.first.error_message).to be_present
    expect(deliveries.first.sent_at).to be_present
  end

  it "records failed delivery history when the endpoint returns a non-success response" do
    create(:webhook_endpoint, event_types: %w[document_updated])
    response = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error").tap do |http_response|
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, "upstream failure")
    end
    http_client = StubWebhookHttp.new(response:)

    deliveries = described_class.new(http_client:).dispatch!(event)

    delivery = deliveries.first
    expect(delivery).to be_failed
    expect(delivery.error_message).to be_blank
    expect(delivery.response_status).to eq(500)
    expect(delivery.response_body).to eq("upstream failure")
    expect(delivery.sent_at).to be_present
  end

  it "truncates long non-success response bodies in the delivery history" do
    create(:webhook_endpoint, event_types: %w[document_updated])
    response_body = "x" * 10_050
    response = Net::HTTPUnprocessableEntity.new("1.1", "422", "Unprocessable Entity").tap do |http_response|
      http_response.instance_variable_set(:@read, true)
      http_response.instance_variable_set(:@body, response_body)
    end
    http_client = StubWebhookHttp.new(response:)

    deliveries = described_class.new(http_client:).dispatch!(event)

    delivery = deliveries.first
    expect(delivery).to be_failed
    expect(delivery.response_status).to eq(422)
    expect(delivery.response_body.length).to eq(10_000)
    expect(delivery.response_body).to start_with("x" * 9_900)
  end

  it "redelivers a failed delivery as a new delivery using the current endpoint settings" do
    endpoint = create(:webhook_endpoint, event_types: %w[document_updated], target_url: "https://example.com/old-webhook")
    failed_delivery = create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      status: :failed,
      target_url: "https://example.com/old-webhook",
      request_body: { stale: true }.to_json,
      error_message: "network error"
    )
    endpoint.update!(target_url: "https://example.com/current-webhook")
    http_client = StubWebhookHttp.new

    redelivery = nil
    expect do
      redelivery = described_class.new(http_client:).redeliver!(failed_delivery)
    end.to change(WebhookDelivery, :count).by(1)

    expect(redelivery).to be_succeeded
    expect(redelivery).not_to eq(failed_delivery)
    expect(redelivery.webhook_endpoint).to eq(endpoint)
    expect(redelivery.notification_event).to eq(event)
    expect(redelivery.target_url).to eq("https://example.com/current-webhook")
    expect(JSON.parse(redelivery.request_body)).to include(
      "id" => event.public_id,
      "event_type" => "document_updated"
    )

    request = http_client.requests.first.request
    expect(request["X-Docs-Portal-Event"]).to eq("document_updated")
  end

  it "keeps redelivery failures in a new delivery history row" do
    endpoint = create(:webhook_endpoint, event_types: %w[document_updated])
    failed_delivery = create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, status: :failed)
    http_client = StubWebhookHttp.new(error: StandardError.new("network error"))

    redelivery = nil
    expect do
      redelivery = described_class.new(http_client:).redeliver!(failed_delivery)
    end.to change(WebhookDelivery, :count).by(1)

    expect(redelivery).to be_failed
    expect(redelivery).not_to eq(failed_delivery)
    expect(redelivery.error_message).to include("network error")
    expect(redelivery.sent_at).to be_present
  end
end
