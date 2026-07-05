require "rails_helper"

RSpec.describe "External folder sync webhooks maintenance mode", type: :request do
  around do |example|
    original_value = ENV[ExternalFolderSyncWebhooksController::READ_ONLY_MAINTENANCE_ENV]
    ENV[ExternalFolderSyncWebhooksController::READ_ONLY_MAINTENANCE_ENV] = "1"
    example.run
  ensure
    if original_value.nil?
      ENV.delete(ExternalFolderSyncWebhooksController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[ExternalFolderSyncWebhooksController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  it "records Google Drive notifications while suppressing sync enqueue" do
    subscription = create(
      :external_folder_sync_subscription,
      provider: :google_drive,
      provider_channel_id: "maintenance-channel",
      provider_resource_id: "maintenance-resource",
      verification_token_digest: Digest::SHA256.hexdigest("maintenance-token")
    )
    allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

    post "/external_folder_sync_webhooks/google_drive", headers: {
      "X-Goog-Channel-ID" => "maintenance-channel",
      "X-Goog-Resource-ID" => "maintenance-resource",
      "X-Goog-Resource-State" => "change",
      "X-Goog-Message-Number" => "501",
      "X-Goog-Channel-Token" => "maintenance-token"
    }

    expect(response).to have_http_status(:ok)
    event = ExternalFolderSyncWebhookEvent.find_by!(event_key: "maintenance-channel:maintenance-resource:change:501")
    expect(event).to be_received
    expect(event.external_folder_sync_subscription).to eq(subscription)
    expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
    expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
  end

  it "keeps SharePoint validation responses provider-compatible without recording events" do
    allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

    expect {
      get "/external_folder_sync_webhooks/sharepoint", params: { validationToken: "maintenance-validation-token" }
    }.not_to change(ExternalFolderSyncWebhookEvent, :count)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.body).to eq("maintenance-validation-token")
    expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)

    expect {
      post "/external_folder_sync_webhooks/sharepoint", params: { validationToken: "post-maintenance-validation-token" }
    }.not_to change(ExternalFolderSyncWebhookEvent, :count)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.body).to eq("post-maintenance-validation-token")
    expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
  end

  it "records SharePoint notifications while suppressing sync enqueue" do
    subscription = create(
      :external_folder_sync_subscription,
      provider: :sharepoint,
      provider_subscription_id: "maintenance-subscription"
    )
    allow(ExternalFolderSyncWebhookEventJob).to receive(:perform_later)

    post "/external_folder_sync_webhooks/sharepoint",
      params: {
        value: [
          {
            subscriptionId: "maintenance-subscription",
            resource: "drives/drive-id/root",
            changeType: "updated",
            clientState: "maintenance-client-state",
            sequenceNumber: "502"
          }
        ]
      }.to_json,
      headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:accepted)
    client_state_fingerprint = "client_state:#{Digest::SHA256.hexdigest("maintenance-client-state")}"
    event = ExternalFolderSyncWebhookEvent.find_by!(
      event_key: "maintenance-subscription:drives/drive-id/root:updated:#{client_state_fingerprint}:502"
    )
    expect(event).to be_received
    expect(event.external_folder_sync_subscription).to eq(subscription)
    expect(event.external_folder_sync_source).to eq(subscription.external_folder_sync_source)
    expect(event.payload_json).to include("clientState" => "[FILTERED]")
    expect(ExternalFolderSyncWebhookEventJob).not_to have_received(:perform_later)
  end
end
