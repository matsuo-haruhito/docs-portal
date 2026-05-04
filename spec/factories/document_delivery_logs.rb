FactoryBot.define do
  factory :document_delivery_log do
    association :project
    association :sender, factory: %i[user internal]
    to_addresses { "client@example.com" }
    subject { "Document delivery" }
    body { "Please review the document." }
    delivery_type { :portal_link }
    status { :draft }
  end
end
