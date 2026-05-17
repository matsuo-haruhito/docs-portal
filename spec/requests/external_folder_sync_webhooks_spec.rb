require "rails_helper"

RSpec.describe "External folder sync webhooks", type: :request do
  describe "POST /external_folder_sync_webhooks/google_drive" do
    it "records a Google Drive notification and enqueues sync processing" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-1",
        provider_resource_id: "resource-1",
        verification_token_digest: Digest::SHA256.hexdigest("token-1")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-1",
        "X-Goog-Resource-ID" => "resource-1",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "42",
        "X-Goog-Channel-Token" => "token-1"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-1:resource-1:change:42")
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.headers_json).to include("X_GOOG_CHANNEL_ID" => "channel-1")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end

    it "does not enqueue duplicate Google Drive notifications" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-dup",
        provider_resource_id: "resource-dup"
      )
      existing_event = create(
        :external_folder_sync_webhook_event,
        external_folder_sync_source: subscription.external_folder_sync_source,
        external_folder_sync_subscription: subscription,
        provider: :google_drive,
        status: :enqueued,
        event_key: "channel-dup:resource-dup:change:7"
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-dup",
        "X-Goog-Resource-ID" => "resource-dup",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "7"
      }

      expect(response).to have_http_status(:ok)
      expect(ExternalFolderSyncWebhookEvent.where(event_key: existing_event.event_key).count).to eq(1)
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "records unmatched Google Drive notifications as ignored" do
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "unknown-channel",
        "X-Goog-Resource-ID" => "unknown-resource",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "1"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "unknown-channel:unknown-resource:change:1")
      expect(event).to be_ignored
      expect(event.error_message).to include("Matching external folder sync source")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end
  end

  describe "GET /external_folder_sync_webhooks/sharepoint" do
    it "responds to Microsoft Graph validationToken" do
      get "/external_folder_sync_webhooks/sharepoint", params: { validationToken: "validation-token" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to eq("validation-token")
    end
  end

  describe "POST /external_folder_sync_webhooks/sharepoint" do
    it "records SharePoint notifications and enqueues sync processing" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-1"
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/sharepoint",
        params: {
          value: [
            {
              subscriptionId: "sub-1",
              resource: "drives/drive-id/root",
              changeType: "updated",
              clientState: "client-state",
              sequenceNumber: "99"
            }
          ]
        }.to_json,
        headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:accepted)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "sub-1:drives/drive-id/root:updated:client-state:99")
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.payload_json).to include("subscriptionId" => "sub-1")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end
  end
end
