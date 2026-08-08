require "openssl"
require "uri"

module WebhookDispatch
  class RequestBuilder
    def initialize(endpoint:, event:, body:, delivery:, target_url: endpoint.target_url)
      @endpoint = endpoint
      @event = event
      @body = body
      @delivery = delivery
      @target_url = target_url
    end

    def call
      uri = URI.parse(target_url)
      request = Net::HTTP::Post.new(uri)
      endpoint.headers_json.each { |key, value| request[key.to_s] = value.to_s }
      apply_reserved_headers!(request)
      request.body = body
      [uri, request]
    end

    private

    attr_reader :endpoint, :event, :body, :delivery, :target_url

    def apply_reserved_headers!(request)
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "docs-portal-webhook"
      request["X-Docs-Portal-Event"] = event.event_type
      request["X-Docs-Portal-Delivery"] = delivery.public_id
      request.delete("X-Docs-Portal-Signature-256")
      if endpoint.secret_token.present?
        request["X-Docs-Portal-Signature-256"] = signature(endpoint.secret_token, body)
      end
    end

    def signature(secret_token, raw_body)
      digest = OpenSSL::HMAC.hexdigest("SHA256", secret_token, raw_body)
      "sha256=#{digest}"
    end
  end
end
