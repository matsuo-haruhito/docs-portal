FactoryBot.define do
  factory :document_bookmark do
    association :user
    association :document
    bookmark_type { :favorite }
  end
end
