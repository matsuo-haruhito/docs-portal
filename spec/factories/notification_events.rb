FactoryBot.define do
  factory :notification_event do
    event_type { :document_updated }
    association :project
    association :document
    association :document_version
    association :actor_user, factory: :user
    sequence(:title) { |n| "Notification #{n}" }
    body { "Notification body" }
    occurred_at { Time.current }
  end
end
