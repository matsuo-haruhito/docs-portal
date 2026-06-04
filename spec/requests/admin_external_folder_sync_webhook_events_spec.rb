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

  it "shows SharePoint webhook events without exposing clientState" do
    sign_in_as(admin_user)
    create(:microsoft_graph_connection, project:, created_by: admin_user)
    microsoft_graph_source = create(
      :external_folder_sync_source,
      project:,
      created_by: admin_user,
      provider: :microsoft_graph,
      auth_type: :microsoft_graph_connection,
      name: "SharePoint sync",
      folder_url: "https://contoso.sharepoint.com/sites/docs/Shared%20Documents/Policies",
      external_folder_id: "folder-item-1",
      external_folder_path: "/Shared Documents/Policies",
      auth_config: "{}"
    )
    create(
      :external_folder_sync_webhook_event,
      external_folder_sync_source: microsoft_graph_source,
      external_folder_sync_subscription: nil,
      provider: :sharepoint,
      status: :failed,
      event_key: "sub-visible:drives/drive-id/items/folder-item-1:updated:sensitive-client-state:102",
      error_message: "Graph resource cannot be matched to a sync item",
      payload_json: {
        "value" => [
          {
            "subscriptionId" => "sub-visible",
            "resource" => "drives/drive-id/items/folder-item-1",
            "changeType" => "updated",
            "clientState" => "sensitive-client-state",
            "sequenceNumber" => "102"
          }
        ],
        "sync_run" => {
          "public_id" => "efsr_visible",
          "status" => "failed",
          "conflict_warnings_count" => 0
        }
      }
    )

    get admin_external_folder_sync_source_path(microsoft_graph_source)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("SharePoint / OneDrive 変更通知の受信イベント")
    expect(response.body).to include("sub-visible")
    expect(response.body).to include("drives/drive-id/items/folder-item-1")
    expect(response.body).to include("updated")
    expect(response.body).to include("102")
    expect(response.body).to include("efsr_visible")
    expect(response.body).to include("Graph resource cannot be matched to a sync item")
    expect(response.body).to include("[masked]")
    expect(response.body).not_to include("sensitive-client-state")
    expect(response.body).to include("差分同期本体、変更通知購読の作成・更新・停止")
  end

  it "keeps the Google Drive subscription table on Google Drive sources" do
    sign_in_as(admin_user)
    create(
      :external_folder_sync_subscription,
      external_folder_sync_source: source,
      provider_channel_id: "channel-visible",
      provider_resource_id: "resource-visible"
    )

    get admin_external_folder_sync_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("変更通知の購読")
    expect(response.body).to include("channel-visible")
    expect(response.body).to include("resource-visible")
    expect(response.body).not_to include("SharePoint / OneDrive 変更通知の受信イベント")
  end
end
