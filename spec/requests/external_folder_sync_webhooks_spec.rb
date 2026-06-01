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

    it "ignores Google Drive notifications when the channel token does not match" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-token-mismatch",
        provider_resource_id: "resource-token-mismatch",
        verification_token_digest: Digest::SHA256.hexdigest("expected-token")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-token-mismatch",
        "X-Goog-Resource-ID" => "resource-token-mismatch",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "43",
        "X-Goog-Channel-Token" => "wrong-token"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-token-mismatch:resource-token-mismatch:change:43")
      expect(event).to be_ignored
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "ignores Google Drive notifications when a required channel token is missing" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-token-missing",
        provider_resource_id: "resource-token-missing",
        verification_token_digest: Digest::SHA256.hexdigest("expected-token")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-token-missing",
        "X-Goog-Resource-ID" => "resource-token-missing",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "44"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-token-missing:resource-token-missing:change:44")
      expect(event).to be_ignored
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "stores malformed Google Drive JSON as raw payload without failing the endpoint" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-malformed",
        provider_resource_id: "resource-malformed",
        verification_token_digest: Digest::SHA256.hexdigest("token-malformed")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive",
        params: "{not-json",
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Goog-Channel-ID" => "channel-malformed",
          "X-Goog-Resource-ID" => "resource-malformed",
          "X-Goog-Resource-State" => "change",
          "X-Goog-Message-Number" => "45",
          "X-Goog-Channel-Token" => "token-malformed"
        }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-malformed:resource-malformed:change:45")
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.payload_json).to eq("raw" => "{not-json")
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

      post_sharepoint_notification(
        subscription_id: "sub-1",
        client_state: "client-state",
        sequence_number: "99"
      )

      expect(response).to have_http_status(:accepted)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "sub-1:drives/drive-id/root:updated:client-state:99")
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.payload_json).to include("subscriptionId" => "sub-1")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end

    it "accepts SharePoint notifications when clientState matches the stored digest" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-secure",
        verification_token_digest: Digest::SHA256.hexdigest("expected-client-state")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post_sharepoint_notification(
        subscription_id: "sub-secure",
        client_state: "expected-client-state",
        sequence_number: "100"
      )

      expect(response).to have_http_status(:accepted)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "sub-secure:drives/drive-id/root:updated:expected-client-state:100")
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.error_message).to be_nil
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end

    it "ignores SharePoint notifications when clientState does not match the stored digest" do
      create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-secure",
        verification_token_digest: Digest::SHA256.hexdigest("expected-client-state")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post_sharepoint_notification(
        subscription_id: "sub-secure",
        client_state: "wrong-client-state",
        sequence_number: "101"
      )

      expect(response).to have_http_status(:accepted)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "sub-secure:drives/drive-id/root:updated:wrong-client-state:101")
      expect(event).to be_ignored
      expect(event.external_folder_sync_source).to be_present
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "records mixed SharePoint notifications and enqueues only received events" do
      received_subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-mixed-received",
        verification_token_digest: Digest::SHA256.hexdigest("expected-client-state")
      )
      ignored_subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-mixed-ignored",
        verification_token_digest: Digest::SHA256.hexdigest("expected-client-state")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/sharepoint",
        params: {
          value: [
            {
              subscriptionId: "sub-mixed-received",
              resource: "drives/drive-id/root",
              changeType: "updated",
              clientState: "expected-client-state",
              sequenceNumber: "201"
            },
            {
              subscriptionId: "sub-mixed-ignored",
              resource: "drives/drive-id/root",
              changeType: "updated",
              clientState: "wrong-client-state",
              sequenceNumber: "202"
            }
          ]
        }.to_json,
        headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:accepted)
      received_event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "sub-mixed-received:drives/drive-id/root:updated:expected-client-state:201")
      ignored_event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "sub-mixed-ignored:drives/drive-id/root:updated:wrong-client-state:202")
      expect(received_event).to be_received
      expect(received_event.external_folder_sync_subscription).to eq(received_subscription)
      expect(ignored_event).to be_ignored
      expect(ignored_event.external_folder_sync_subscription).to eq(ignored_subscription)
      expect(ignored_event.external_folder_sync_source).to be_present
      expect(ignored_event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(received_event.id).once
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later).with(ignored_event.id)
    end
  end

  def post_sharepoint_notification(subscription_id:, client_state:, sequence_number:)
    post "/external_folder_sync_webhooks/sharepoint",
      params: {
        value: [
          {
            subscriptionId: subscription_id,
            resource: "drives/drive-id/root",
            changeType: "updated",
            clientState: client_state,
            sequenceNumber: sequence_number
          }
        ]
      }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }
  end
end
