FactoryBot.define do
  factory :document_approval_request do
    association :document
    association :requester, factory: %i[user internal]
    title { "Please confirm" }
    body { "Review before proceed." }
    status { :pending }
  end
end
