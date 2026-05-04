FactoryBot.define do
  factory :document_review_comment do
    association :document
    document_version { document.latest_version }
    association :author, factory: %i[user internal]
    comment_type { :note }
    status { :open }
    body { "Please review this document." }
    internal_only { true }
  end
end
