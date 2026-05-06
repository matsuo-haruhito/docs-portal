FactoryBot.define do
  factory :webhook_delivery do
    association :webhook_endpoint
    association :notification_event
    status { :pending }
    event_type { notification_event.event_type }
    target_url { webhook_endpoint.target_url }
    request_body { { id: notification_event.public_id, event_type: notification_event.event_type }.to_json }
  end
end
