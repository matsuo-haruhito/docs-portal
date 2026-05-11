FactoryBot.define do
  factory :external_folder_sync_source do
    project
    association :created_by, factory: [:user, :internal]
    provider { :google_drive }
    auth_type { :oauth_user }
    sequence(:name) { |n| "Google Drive Sync #{n}" }
    folder_url { "https://drive.google.com/drive/folders/folder-id" }
    external_folder_id { "folder-id" }
    external_folder_path { nil }
    sync_direction { :external_to_portal }
    conflict_policy { :manual }
    enabled { true }
    auth_config { "{}" }
  end

  factory :external_folder_sync_subscription do
    external_folder_sync_source
    provider { :google_drive }
    status { :active }
    sequence(:provider_channel_id) { |n| "channel-#{n}" }
    sequence(:provider_resource_id) { |n| "resource-#{n}" }
    callback_url { "https://portal.example.com/external_folder_sync_webhooks/google_drive" }
    expires_at { 1.day.from_now }
  end

  factory :external_folder_sync_webhook_event do
    external_folder_sync_source
    external_folder_sync_subscription
    provider { :google_drive }
    status { :received }
    sequence(:event_key) { |n| "event-#{n}" }
    received_at { Time.current }
    headers_json { {} }
    payload_json { {} }
  end
end
