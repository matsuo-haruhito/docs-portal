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

    it "records token mismatch notifications as ignored without enqueueing" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-secure",
        provider_resource_id: "resource-secure",
        verification_token_digest: Digest::SHA256.hexdigest("expected-token")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-secure",
        "X-Goog-Resource-ID" => "resource-secure",
        "X-Goog-Resource-State" => "change",
        "X-Goog-Message-Number" => "43",
        "X-Goog-Channel-Token" => "wrong-token"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-secure:resource-secure:change:43")
      expect(event).to be_ignored
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "requires the channel token when the Google Drive subscription stores a token digest" do
      create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-missing-token",
        provider_resource_id: "resource-missing-token",
        verification_token_digest: Digest::SHA256.hexdigest("expected-token")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive", headers: {
        "X-Goog-Channel-ID" => "channel-missing-token",
        "X-Goog-Resource-ID" => "resource-missing-token",
        "X-Goog-Resource-State" => "sync",
        "X-Goog-Message-Number" => "44"
      }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-missing-token:resource-missing-token:sync:44")
      expect(event).to be_ignored
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "stores malformed JSON as raw payload without rejecting the webhook" do
      subscription = create(
        :external_folder_sync_subscription,
        provider: :google_drive,
        provider_channel_id: "channel-raw",
        provider_resource_id: "resource-raw",
        verification_token_digest: Digest::SHA256.hexdigest("token-raw")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post "/external_folder_sync_webhooks/google_drive",
        params: "{not-json",
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Goog-Channel-ID" => "channel-raw",
          "X-Goog-Resource-ID" => "resource-raw",
          "X-Goog-Resource-State" => "change",
          "X-Goog-Message-Number" => "45",
          "X-Goog-Channel-Token" => "token-raw"
        }

      expect(response).to have_http_status(:ok)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "channel-raw:resource-raw:change:45")
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.payload_json).to eq("raw" => "{not-json")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end
  end

  describe "GET /external_folder_sync_webhooks/sharepoint" do
    it "responds to Microsoft Graph validationToken" do
      get "/external_folder_sync_webhooks/sharepoint", params: { validationToken: "validation-token" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to eq("validation-token")
    end

    it "does not record or enqueue events for Microsoft Graph validationToken checks" do
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      expect {
        get "/external_folder_sync_webhooks/sharepoint", params: { validationToken: "validation-token" }
      }.not_to change(ExternalFolderSyncWebhookEvent, :count)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to eq("validation-token")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
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
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: sharepoint_event_key("sub-1", "client-state", "99"))
      expect(event).to be_received
      expect(event.external_folder_sync_subscription).to eq(subscription)
      expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
      expect(event.payload_json).to include("subscriptionId" => "sub-1")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(event.id).once
    end

    it "records unmatched SharePoint notifications as ignored without enqueueing" do
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post_sharepoint_notification(
        subscription_id: "unknown-subscription",
        client_state: "client-state",
        sequence_number: "98"
      )

      expect(response).to have_http_status(:accepted)
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: sharepoint_event_key("unknown-subscription", "client-state", "98"))
      expect(event).to be_ignored
      expect(event.external_folder_sync_subscription).to be_nil
      expect(event.external_folder_sync_source).to be_nil
      expect(event.error_message).to eq("Matching external folder sync source was not found")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
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
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: sharepoint_event_key("sub-secure", "expected-client-state", "100"))
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
      event = ExternalFolderSyncWebhookEvent.find_by!(event_key: sharepoint_event_key("sub-secure", "wrong-client-state", "101"))
      expect(event).to be_ignored
      expect(event.external_folder_sync_source).to be_present
      expect(event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
    end

    it "records each SharePoint notification and only enqueues verified received events" do
      received_subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-received"
      )
      ignored_subscription = create(
        :external_folder_sync_subscription,
        provider: :sharepoint,
        provider_subscription_id: "sub-ignored",
        verification_token_digest: Digest::SHA256.hexdigest("expected-client-state")
      )
      allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

      post_sharepoint_notifications([
        sharepoint_notification_hash(
          subscription_id: "sub-received",
          client_state: "client-state",
          sequence_number: "102"
        ),
        sharepoint_notification_hash(
          subscription_id: "sub-ignored",
          client_state: "wrong-client-state",
          sequence_number: "103"
        )
      ])

      expect(response).to have_http_status(:accepted)
      received_event = ExternalFolderSyncWebhookEvent.find_by!(event_key: sharepoint_event_key("sub-received", "client-state", "102"))
      ignored_event = ExternalFolderSyncWebhookEvent.find_by!(event_key: sharepoint_event_key("sub-ignored", "wrong-client-state", "103"))
      expect(received_event).to be_received
      expect(received_event.external_folder_sync_subscription).to eq(received_subscription)
      expect(ignored_event).to be_ignored
      expect(ignored_event.external_folder_sync_subscription).to eq(ignored_subscription)
      expect(ignored_event.error_message).to eq("Webhook verification token did not match")
      expect(ExternalFolderSyncWebhookEventJob).to have_received(:perform_later).with(received_event.id).once
      expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later).with(ignored_event.id)
    end
  end

  def sharepoint_event_key(subscription_id, client_state, sequence_number)
    client_state_fingerprint = "client_state:#{Digest::SHA256.hexdigest(client_state)}"

    "#{subscription_id}:drives/drive-id/root:updated:#{client_state_fingerprint}:#{sequence_number}"
  end

  def post_sharepoint_notification(subscription_id:, client_state:, sequence_number:)
    post_sharepoint_notifications([
      sharepoint_notification_hash(
        subscription_id: subscription_id,
        client_state: client_state,
        sequence_number: sequence_number
      )
    ])
  end

  def post_sharepoint_notifications(notifications)
    post "/external_folder_sync_webhooks/sharepoint",
      params: { value: notifications }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }
  end

  def sharepoint_notification_hash(subscription_id:, client_state:, sequence_number:)
    {
      subscriptionId: subscription_id,
      resource: "drives/drive-id/root",
      changeType: "updated",
      clientState: client_state,
      sequenceNumber: sequence_number
    }
  end
end
