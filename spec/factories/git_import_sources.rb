FactoryBot.define do
  factory :git_import_source do
    project
    association :created_by, factory: [:user, :internal]
    provider { :github }
    sequence(:repository_full_name) { |n| "example/private-docs-#{n}" }
    branch { "main" }
    source_path { "docs" }
    auth_type { :github_app }
    enabled { true }
  end
end
