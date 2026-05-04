FactoryBot.define do
  factory :document_permission do
    association :document
    company { user.present? ? nil : association(:company) }
    user { nil }
    access_level { :view }

    trait :user_scoped do
      company { nil }
      association :user
    end

    trait :company_scoped do
      association :company
      user { nil }
    end
  end
end
