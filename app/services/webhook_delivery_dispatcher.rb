require "net/http"
require "openssl"
require "uri"

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
    payload = payload_for(event)
    body = JSON.generate(payload)
    delivery = WebhookDelivery.create!(
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: event.event_type,
      target_url: endpoint.target_url,
      request_body: body
    )

    response = post(endpoint, event, body)
    delivery.update!(
      status: response.is_a?(Net::HTTPSuccess) ? :succeeded : :failed,
      response_status: response.code.to_i,
      response_body: response.body.to_s.truncate(10_000),
      sent_at: Time.current
    )
    delivery
  rescue StandardError => e
    delivery&.update!(status: :failed, error_message: e.message.truncate(10_000), sent_at: Time.current)
    delivery || WebhookDelivery.create!(
      webhook_endpoint: endpoint,
      notification_event: event,
      status: :failed,
      event_type: event.event_type,
      target_url: endpoint.target_url,
      request_body: body || "{}",
      error_message: e.message.truncate(10_000),
      sent_at: Time.current
    )
  end

  def post(endpoint, event, body)
    uri = URI.parse(endpoint.target_url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["User-Agent"] = "docs-portal-webhook"
    request["X-Docs-Portal-Event"] = event.event_type
    request["X-Docs-Portal-Delivery"] = event.public_id
    request["X-Docs-Portal-Signature-256"] = signature(endpoint.secret_token, body) if endpoint.secret_token.present?
    endpoint.headers_json.each { |key, value| request[key.to_s] = value.to_s }
    request.body = body

    http_client.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      http.request(request)
    end
  end

  def signature(secret_token, body)
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret_token, body)
    "sha256=#{digest}"
  end

  def payload_for(event)
    {
      id: event.public_id,
      event_type: event.event_type,
      occurred_at: event.occurred_at.iso8601,
      title: event.title,
      body: event.body,
      project: event.project && { id: event.project.public_id, code: event.project.code, name: event.project.name },
      document: event.document && { id: event.document.public_id, slug: event.document.slug, title: event.document.title },
      document_version: event.document_version && { id: event.document_version.public_id, version_label: event.document_version.version_label },
      actor: event.actor_user && { id: event.actor_user.public_id, email_address: event.actor_user.email_address, name: event.actor_user.name }
    }.compact
  end
end
