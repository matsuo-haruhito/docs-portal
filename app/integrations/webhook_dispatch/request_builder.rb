require "openssl"
require "uri"

module WebhookDispatch
  class RequestBuilder
    def initialize(endpoint:, event:, body:)
      @endpoint = endpoint
      @event = event
      @body = body
    end

    def call
      uri = URI.parse(endpoint.target_url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "docs-portal-webhook"
      request["X-Docs-Portal-Event"] = event.event_type
      request["X-Docs-Portal-Delivery"] = event.public_id
      request["X-Docs-Portal-Signature-256"] = signature(endpoint.secret_token, body) if endpoint.secret_token.present?
      endpoint.headers_json.each { |key, value| request[key.to_s] = value.to_s }
      request.body = body
      [uri, request]
    end

    private

    attr_reader :endpoint, :event, :body

    def signature(secret_token, raw_body)
      digest = OpenSSL::HMAC.hexdigest("SHA256", secret_token, raw_body)
      "sha256=#{digest}"
    end
  end
end
