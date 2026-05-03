FactoryBot.define do
  factory :project do
    sequence(:code) { |n| "SPEC_PJ#{n.to_s.rjust(3, '0')}" }
    sequence(:name) { |n| "Project #{n}" }
    description { "Project description" }
    active { true }
  end
end
