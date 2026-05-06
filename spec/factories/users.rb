FactoryBot.define do
  factory :user do
    association :company
    sequence(:name) { |n| "User #{n}" }
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123!" }
    password_confirmation { "password123!" }
    user_type { :internal }
    active { true }

    trait :internal do
      user_type { :internal }
    end

    trait :admin do
      user_type { :internal }
    end

    trait :external do
      user_type { :external }
    end

    trait :company_master_admin do
      user_type { :company_master_admin }
    end
  end
end
