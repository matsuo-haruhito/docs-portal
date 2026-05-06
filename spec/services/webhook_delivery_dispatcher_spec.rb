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
end
