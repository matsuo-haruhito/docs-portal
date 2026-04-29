FactoryBot.define do
  factory :project_membership do
    association :project
    association :user
    role { :member }
  end
end
