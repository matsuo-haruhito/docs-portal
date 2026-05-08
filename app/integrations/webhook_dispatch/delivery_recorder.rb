module WebhookDispatch
  class DeliveryRecorder
    def initialize(endpoint:, event:, body:)
      @endpoint = endpoint
      @event = event
      @body = body
    end

    def start!
      WebhookDelivery.create!(
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: event.event_type,
        target_url: endpoint.target_url,
        request_body: body
      )
    end

    def succeed!(delivery:, response:)
      delivery.update!(
        status: response.is_a?(Net::HTTPSuccess) ? :succeeded : :failed,
        response_status: response.code.to_i,
        response_body: response.body.to_s.truncate(10_000),
        sent_at: Time.current
      )
      delivery
    end

    def fail!(delivery:, error:)
      delivery&.update!(status: :failed, error_message: error.message.truncate(10_000), sent_at: Time.current)
      delivery || WebhookDelivery.create!(
        webhook_endpoint: endpoint,
        notification_event: event,
        status: :failed,
        event_type: event.event_type,
        target_url: endpoint.target_url,
        request_body: body || "{}",
        error_message: error.message.truncate(10_000),
        sent_at: Time.current
      )
    end

    private

    attr_reader :endpoint, :event, :body
  end
end
