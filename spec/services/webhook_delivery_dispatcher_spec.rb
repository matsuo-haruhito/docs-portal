require "rails_helper"
require "openssl"

RSpec.describe WebhookDeliveryDispatcher do
  class StubWebhookHttp
    Request = Struct.new(:uri, :request)

    attr_reader :requests

    def initialize(response: Net::HTTPOK.new("1.1", "200", "OK"), error: nil)
      @response = response
      @error = error
      @requests = []
    end

    def start(host, port, use_ssl:, open_timeout:, read_timeout:)
      http = Struct.new(:client) do
        def request(request)
          client.requests << Request.new([request.uri.hostname, request.uri.port, request.uri.scheme], request)
          raise client.error if client.error

          client.response.tap { |response| response.body = "accepted" }
        end
      end.new(self)

      yield http
    end

    protected

    attr_reader :response, :error
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

  it "delivers subscribed events with a signed JSON payload" do
    endpoint = create(:webhook_endpoint, event_types: %w[document_updated], secret_token: "top-secret")
    create(:webhook_endpoint, event_types: %w[document_published])
    http_client = StubWebhookHttp.new

    deliveries = described_class.new(http_client:).dispatch!(event)

    expect(deliveries.size).to eq(1)
    delivery = deliveries.first
    expect(delivery.webhook_endpoint).to eq(endpoint)
    expect(delivery).to be_succeeded
    expect(delivery.response_status).to eq(200)
    expect(JSON.parse(delivery.request_body)).to include(
      "id" => event.public_id,
      "event_type" => "document_updated",
      "title" => "Webhook対象文書 が更新されました"
    )

    request = http_client.requests.first.request
    expected_signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'top-secret', delivery.request_body)}"
    expect(request["X-Docs-Portal-Event"]).to eq("document_updated")
    expect(request["X-Docs-Portal-Signature-256"]).to eq(expected_signature)
  end

  it "records failed delivery history when the request fails" do
    create(:webhook_endpoint, event_types: %w[document_updated])
    http_client = StubWebhookHttp.new(error: Errno::ECONNREFUSED.new)

    deliveries = described_class.new(http_client:).dispatch!(event)

    expect(deliveries.first).to be_failed
    expect(deliveries.first.error_message).to be_present
    expect(deliveries.first.sent_at).to be_present
  end
end
