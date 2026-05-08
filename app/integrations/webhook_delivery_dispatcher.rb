require "net/http"
class WebhookDeliveryDispatcher
  TIMEOUT_SECONDS = 5

  def initialize(http_client: Net::HTTP)
    @http_client = http_client
  end

  def dispatch!(event)
    WebhookEndpoint.subscribed_to(event.event_type).map do |endpoint|
      deliver_to_endpoint!(endpoint, event)
    end
  end

  private

  attr_reader :http_client

  def deliver_to_endpoint!(endpoint, event)
    payload = WebhookDispatch::PayloadBuilder.new(event:).call
    body = JSON.generate(payload)
    recorder = WebhookDispatch::DeliveryRecorder.new(endpoint:, event:, body:)
    delivery = recorder.start!

    response = post(endpoint, event, body)
    recorder.succeed!(delivery:, response:)
  rescue StandardError => e
    recorder&.fail!(delivery:, error: e)
  end

  def post(endpoint, event, body)
    uri, request = WebhookDispatch::RequestBuilder.new(endpoint:, event:, body:).call

    http_client.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      http.request(request)
    end
  end
end
