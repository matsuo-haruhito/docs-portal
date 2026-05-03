FactoryBot.define do
  factory :notification_receipt do
    association :notification_event
    association :user
    read_at { nil }
  end
end
