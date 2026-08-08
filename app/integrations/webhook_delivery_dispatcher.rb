require "net/http"

class WebhookDeliveryDispatcher
  TIMEOUT_SECONDS = 5
  RESPONSE_BODY_LIMIT = 10_000

  def initialize(http_client: Net::HTTP)
    @http_client = http_client
  end

  def dispatch!(event)
    WebhookEndpoint.subscribed_to(event.event_type).map do |endpoint|
      deliver_to_endpoint!(endpoint, event)
    end
  end

  def redeliver!(delivery)
    deliver_to_endpoint!(delivery.webhook_endpoint, delivery.notification_event)
  end

  def retry_in_place!(delivery)
    claim_token = delivery.claim_auto_retry!
    unless claim_token
      raise ApplicationError::BadRequest, "このWebhook送信履歴は自動再送の対象ではありません。"
    end

    endpoint = delivery.webhook_endpoint
    event = delivery.notification_event
    body = delivery.request_body
    response = post(endpoint, event, body, delivery:, target_url: delivery.target_url)
    complete_auto_retry_response!(delivery, claim_token, response)
    delivery
  rescue StandardError => e
    raise unless claim_token

    complete_auto_retry_error!(delivery, claim_token, e)
    delivery
  end

  private

  attr_reader :http_client

  def deliver_to_endpoint!(endpoint, event)
    payload = WebhookDispatch::PayloadBuilder.new(event:).call
    body = JSON.generate(payload)
    recorder = WebhookDispatch::DeliveryRecorder.new(endpoint:, event:, body:)
    delivery = recorder.start!

    deliver_and_record!(endpoint:, event:, body:, delivery:, recorder:)
  rescue StandardError => e
    recorder&.fail!(delivery:, error: e)
  end

  def deliver_and_record!(endpoint:, event:, body:, delivery:, recorder:, target_url: endpoint.target_url)
    response = post(endpoint, event, body, delivery:, target_url:)
    recorder.succeed!(delivery:, response:)
  rescue StandardError => e
    recorder.fail!(delivery:, error: e)
  end

  def complete_auto_retry_response!(delivery, claim_token, response)
    delivery.complete_auto_retry!(
      claim_token:,
      status: response.is_a?(Net::HTTPSuccess) ? :succeeded : :failed,
      response_status: response.code.to_i,
      response_body: response.body.to_s.truncate(RESPONSE_BODY_LIMIT),
      error_message: nil,
      at: Time.current
    )
  end

  def complete_auto_retry_error!(delivery, claim_token, error)
    delivery.complete_auto_retry!(
      claim_token:,
      status: :failed,
      response_status: nil,
      response_body: nil,
      error_message: error.message.truncate(RESPONSE_BODY_LIMIT),
      at: Time.current
    )
  end

  def post(endpoint, event, body, delivery:, target_url: endpoint.target_url)
    uri, request = WebhookDispatch::RequestBuilder.new(endpoint:, event:, body:, delivery:, target_url:).call

    http_client.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      http.request(request)
    end
  end
end
