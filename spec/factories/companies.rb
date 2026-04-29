FactoryBot.define do
  factory :company do
    sequence(:code) { |n| "COMP#{n}" }
    sequence(:name) { |n| "Company #{n}" }
    active { true }
  end
end
