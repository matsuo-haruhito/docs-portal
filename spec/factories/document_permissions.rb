FactoryBot.define do
  factory :document_permission do
    association :document
    association :company
    user { nil }
    access_level { :view }
  end
end
