FactoryBot.define do
  factory :microsoft_graph_connection do
    project
    association :created_by, factory: [:user, :internal]
    sequence(:name) { |n| "Office preview #{n}" }
    auth_type { :client_credentials }
    tenant_id { SecureRandom.uuid }
    client_id { SecureRandom.uuid }
    client_secret { "client-secret" }
    drive_id { "drive-id" }
    preview_folder_path { "docs-portal-previews" }
    enabled { true }
  end
end
