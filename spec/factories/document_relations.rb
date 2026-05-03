FactoryBot.define do
  factory :document_relation do
    association :source_document, factory: :document
    association :target_document, factory: :document
    relation_type { :related }
    sort_order { 0 }
  end
end
