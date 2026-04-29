FactoryBot.define do
  factory :document_version do
    association :document
    sequence(:version_label) { |n| "v1.0.#{n}" }
    status { :published }
    source_commit_hash { "deadbeef" }
    site_build_path { nil }
  end
end
