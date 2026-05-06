FactoryBot.define do
  factory :webhook_endpoint do
    sequence(:name) { |n| "Webhook Endpoint #{n}" }
    target_url { "https://example.com/webhooks/docs-portal" }
    secret_token { "secret-token" }
    active { true }
    event_types { %w[document_updated] }
  end
end
