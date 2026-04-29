FactoryBot.define do
  factory :document do
    association :project
    sequence(:title) { |n| "Document #{n}" }
    sequence(:slug) { |n| "document-#{n}" }
    category { :spec }
    document_kind { :markdown }
    visibility_policy { :restricted_external }
  end
end
