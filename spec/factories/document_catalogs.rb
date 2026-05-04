FactoryBot.define do
  factory :document_catalog do
    association :project
    name { "Customer Catalog" }
    description { "Documents for a customer audience." }
    audience_type { :customer }
    visibility_policy { :restricted_external }
    sort_order { 0 }
  end

  factory :document_catalog_item do
    association :document_catalog
    association :document
    sort_order { 0 }
    note { nil }
  end
end
