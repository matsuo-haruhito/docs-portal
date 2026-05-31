require "rails_helper"

RSpec.describe "Admin external folder sync webhook events", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC-WEBHOOK", name: "Webhook Project") }
  let(:source) do
    create(
      :external_folder_sync_source,
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :service_account,
      auth_config: { client_email: "sync@example.com" }.to_json
    )
  end
  let(:subscription) { create(:external_folder_sync_subscription, external_folder_sync_source: source) }

  it "distinguishes coalesced ignored events from permanent ignored events" do
    sign_in_as(admin_user)
    create(
      :external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_subscription: subscription,
      status: :ignored,
      error_message: ExternalFolderSyncWebhookEvent::RUNNING_COALESCED_ERROR_MESSAGE
    )
    create(
      :external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_subscription: subscription,
      status: :ignored,
      error_message: ExternalFolderSyncWebhookEvent::RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE
    )
    create(
      :external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_subscription: subscription,
      status: :ignored,
      error_message: ExternalFolderSyncWebhookEvent::SOURCE_UNAVAILABLE_ERROR_MESSAGE
    )

    get admin_external_folder_sync_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("無視（実行中のため集約）")
    expect(response.body).to include("無視（登録済みジョブへ集約）")
    expect(response.body).to include("無視（同期元なし / 無効）")
    expect(response.body).to include(ExternalFolderSyncWebhookEvent::RUNNING_COALESCED_ERROR_MESSAGE)
    expect(response.body).to include(ExternalFolderSyncWebhookEvent::RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE)
    expect(response.body).to include(ExternalFolderSyncWebhookEvent::SOURCE_UNAVAILABLE_ERROR_MESSAGE)
  end
end
