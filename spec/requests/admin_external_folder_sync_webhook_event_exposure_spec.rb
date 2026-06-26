require "rails_helper"

RSpec.describe "Admin external folder sync webhook event exposure", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC-WEBHOOK", name: "Sync Webhook Project") }

  def create_google_drive_source(name: "Google webhook source")
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :service_account,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: { client_email: "sync@example.com" }.to_json
    )
  end

  def create_microsoft_graph_source(name: "SharePoint webhook source")
    create(:microsoft_graph_connection, project:, enabled: true)

    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :microsoft_graph,
      auth_type: :microsoft_graph_connection,
      name:,
      folder_url: "https://contoso.sharepoint.com/:f:/s/#{name.parameterize}/ExampleFolder",
      external_folder_id: "item-#{name.parameterize}",
      external_folder_path: "Shared Documents/#{name}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {
        "drive_id" => "drive-#{name.parameterize}",
        "folder_item_id" => "item-#{name.parameterize}",
        "folder_path" => "Shared Documents/#{name}"
      }
    )
  end

  describe "Google Drive webhook event details" do
    it "does not persist or render the verification token while keeping operational ids visible" do
      token = "goog-channel-token-raw-secret"
      source = create_google_drive_source
      ExternalFolderSyncSubscription.create!(
        external_folder_sync_source: source,
        provider: :google_drive,
        status: :active,
        provider_channel_id: "goog-channel-123",
        provider_resource_id: "goog-resource-456",
        callback_url: "https://example.com/external_folder_sync_webhooks/google_drive",
        expires_at: 1.day.from_now,
        verification_token_digest: Digest::SHA256.hexdigest(token)
      )

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "goog-channel-123",
        "X-Goog-Resource-ID" => "goog-resource-456",
        "X-Goog-Resource-State" => "update",
        "X-Goog-Message-Number" => "7",
        "X-Goog-Channel-Token" => token,
        "User-Agent" => "Google-Webhook"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.google_drive.order(:id).last
      expect(event).to be_received
      expect(event.headers_json).to include(
        "X_GOOG_CHANNEL_ID" => "goog-channel-123",
        "X_GOOG_RESOURCE_ID" => "goog-resource-456",
        "X_GOOG_MESSAGE_NUMBER" => "7"
      )
      expect(event.headers_json).not_to include("X_GOOG_CHANNEL_TOKEN")
      expect(event.headers_json.values).not_to include(token)

      sign_in_as(admin_user)
      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("goog-channel-123")
      expect(response.body).to include("goog-resource-456")
      expect(response.body).to include("7")
      expect(response.body).not_to include(token)
    end
  end

  describe "SharePoint webhook event details" do
    it "does not persist or render raw clientState while keeping non-secret notification context visible" do
      client_state = "sharepoint-client-state-raw-secret"
      source = create_microsoft_graph_source
      ExternalFolderSyncSubscription.create!(
        external_folder_sync_source: source,
        provider: :sharepoint,
        status: :active,
        provider_subscription_id: "sub-123",
        callback_url: "https://example.com/external_folder_sync_webhooks/sharepoint",
        expires_at: 1.day.from_now,
        verification_token_digest: Digest::SHA256.hexdigest(client_state)
      )
      payload = {
        value: [
          {
            subscriptionId: "sub-123",
            resource: "sites/site-1/drives/drive-1/root",
            changeType: "updated",
            clientState: client_state,
            sequenceNumber: "42"
          }
        ]
      }

      post "/external_folder_sync_webhooks/sharepoint", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:accepted)
      event = ExternalFolderSyncWebhookEvent.sharepoint.order(:id).last
      expect(event).to be_received
      expect(event.payload_json).to include(
        "subscriptionId" => "sub-123",
        "resource" => "sites/site-1/drives/drive-1/root",
        "changeType" => "updated",
        "clientState" => "[FILTERED]",
        "sequenceNumber" => "42"
      )
      expect(event.event_key).to include(Digest::SHA256.hexdigest(client_state))
      expect(event.event_key).not_to include(client_state)
      expect(event.payload_json.values).not_to include(client_state)

      sign_in_as(admin_user)
      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("sub-123")
      expect(response.body).to include("sites/site-1/drives/drive-1/root")
      expect(response.body).to include("updated")
      expect(response.body).to include("42")
      expect(response.body).not_to include(client_state)
    end
  end
end
