FactoryBot.define do
  factory :read_confirmation do
    association :user
    association :document
    document_version { document.latest_version }
    confirmed_at { Time.current }
  end
end
