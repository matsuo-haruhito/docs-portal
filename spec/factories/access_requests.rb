FactoryBot.define do
  factory :access_request do
    association :requester, factory: %i[user external]
    association :requestable, factory: :project
    requested_access_level { :view }
    status { :pending }
    reason { "Need access for project work." }
  end
end
