require "rails_helper"

RSpec.describe "External folder sync webhook event sanitization", type: :request do
  describe "Google Drive notifications" do
    it "uses the channel token for verification without storing it" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-secret",
        provider_resource_id: "resource-secret",
        verification_token_digest: Digest::SHA256.hexdigest("raw-channel-token")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-secret",
        "X-Goog-Resource-ID" => "resource-secret",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "77",
        "X-Goog-Channel-Token" => "raw-channel-token"
      }

      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-secret:resource-secret:change:77")
      expect(response).to have_http_status(:ok)
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.headers_json).to include(
        "X_GOOG_CHANNEL_ID" => "channel-secret",
        "X_GOOG_RESOURCE_ID" => "resource-secret",
        "X_GOOG_RESOURCE_STATE" => "change",
        "X_GOOG_MESSAGE_NUMBER" => "77"
      )
      expect(event.headers_json).not_to have_key("X_GOOG_CHANNEL_TOKEN")
      expect(event.headers_json.to_json).not_to include("raw-channel-token")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end

    it "does not store a mismatched channel token on ignored events" do
      create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-mismatch",
        provider_resource_id: "resource-mismatch",
        verification_token_digest: Digest::SHA256.hexdigest("expected-channel-token")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-mismatch",
        "X-Goog-Resource-ID" => "resource-mismatch",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "78",
        "X-Goog-Channel-Token" => "wrong-channel-token"
      }

      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-mismatch:resource-mismatch:change:78")
      expect(response).to have_http_status(:ok)
      expect(event).to be_ignored
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(event.headers_json).not_to have_key("X_GOOG_CHANNEL_TOKEN")
      expect(event.headers_json.to_json).not_to include("wrong-channel-token")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end
  end

  describe "SharePoint notifications" do
    it "filters clientState from stored payload and event keys while preserving notification identifiers" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-secret",
        verification_token_digest: Digest::SHA256.hexdigest("raw-client-state")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/sharepoint",
        params: {
          value: [
            {
              subscriptionId: "sub-secret",
              resource: "drives/drive-id/root",
              changeType: "updated",
              clientState: "raw-client-state",
              sequenceNumber: "123"
            }
          ]
        }.to_json,
        headers: { "CONTENT_TYPE" => "application/json" }

      client_state_fingerprint = "client_state:#{Digest::SHA256.hexdigest('raw-client-state')}"
      event = ExternalFolderSyncWebhookEvent.find_by!(
        event_key: "sub-secret:drives/drive-id/root:updated:#{client_state_fingerprint}:123"
      )
      expect(response).to have_http_status(:accepted)
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.payload_json).to include(
        "subscriptionId" => "sub-secret",
        "resource" => "drives/drive-id/root",
        "changeType" => "updated",
        "clientState" => "[FILTERED]",
        "sequenceNumber" => "123"
      )
      expect(event.payload_json.to_json).not_to include("raw-client-state")
      expect(event.event_key).to include(client_state_fingerprint)
      expect(event.event_key).not_to include("raw-client-state")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end
  end
end
