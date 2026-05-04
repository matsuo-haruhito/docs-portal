FactoryBot.define do
  factory :document_set do
    association :project
    name { "Document Set" }
    description { "A grouped set of documents." }
    set_type { :delivery }
    visibility_policy { :restricted_external }
    sort_order { 0 }
  end

  factory :document_set_item do
    association :document_set
    association :document
    sort_order { 0 }
  end
end
