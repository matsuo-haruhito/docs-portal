FactoryBot.define do
  factory :company do
    sequence(:domain) { |n| "company#{n}.example.com" }
    sequence(:name) { |n| "Company #{n}" }
    active { true }
  end
end
