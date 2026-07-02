require "rails_helper"

RSpec.describe "Admin external folder sync source empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNCITEM", name: "Sync Item Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_google_drive_source(name: "Drive docs")
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

  def create_microsoft_graph_source(name: "Graph docs")
    MicrosoftGraphConnection.create!(
      project:,
      created_by: admin_user,
      name: "Graph connection #{name}",
      auth_type: :client_credentials,
      tenant_id: "tenant-#{name.parameterize}",
      client_id: "client-#{name.parameterize}",
      client_secret: "secret-#{name.parameterize}",
      drive_id: "drive-#{name.parameterize}",
      preview_folder_path: "Shared Documents",
      enabled: true
    )

    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :microsoft_graph,
      auth_type: :microsoft_graph_connection,
      name:,
      folder_url: "https://contoso.sharepoint.com/sites/docs/Shared%20Documents/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      external_folder_path: "Shared Documents/#{name}",
      provider_metadata: {
        "drive_id" => "drive-#{name.parameterize}",
        "folder_path" => "Shared Documents/#{name}",
        "site_id" => "site-#{name.parameterize}"
      },
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json
    )
  end

  def card_text(heading)
    card = parsed_html.xpath("//h2[normalize-space()='#{heading}']/ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' card ')][1]").first
    expect(card).to be_present
    card.text.squish
  end

  def sync_items_card_text
    card_text("同期アイテム")
  end

  def webhook_events_card_text(heading = "変更通知の受信イベント")
    card_text(heading)
  end

  describe "GET /admin/external_folder_sync_sources/:public_id" do
    it "shows a read-only sync item empty state when no sync items exist" do
      sign_in_as(admin_user)
      source = create_google_drive_source

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      text = sync_items_card_text
      expect(text).to include("同期アイテム")
      expect(text).to include("まだ同期アイテムはありません。")
      expect(text).to include("同期内容の確認または同期を実行すると、外部フォルダ内のファイルとポータル文書の対応がここに表示されます。")
      expect(text).to include("詳細は上の同期履歴の「結果詳細」で確認してください。")
    end

    it "keeps existing sync item rows and hides the empty state when sync items exist" do
      sign_in_as(admin_user)
      source = create_google_drive_source
      ExternalFolderSyncItem.create!(
        external_folder_sync_source: source,
        external_item_id: "drive-file-1",
        path: "Policies/handbook.pdf",
        name: "handbook.pdf",
        size: 1234,
        external_modified_at: Time.zone.parse("2026-01-15 09:30"),
        sync_status: :synced
      )

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      text = sync_items_card_text
      expect(text).to include("Policies/handbook.pdf")
      expect(text).to include("1234")
      expect(text).not_to include("まだ同期アイテムはありません。")
    end

    it "shows a Google Drive webhook event empty state without implying sync success" do
      sign_in_as(admin_user)
      source = create_google_drive_source

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      text = webhook_events_card_text
      expect(text).to include("まだ変更通知イベントは受信していません。")
      expect(text).to include("購読を開始すると、受信した通知と同期履歴への紐づきがここに表示されます。")
      expect(text).to include("同期成功や購読済みを保証する表示ではありません。")
    end

    it "shows a Microsoft Graph webhook event empty state as a read-only event cue" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      text = webhook_events_card_text("SharePoint / OneDrive 変更通知の受信イベント")
      expect(text).to include("まだ受信済み webhook event はありません。")
      expect(text).to include("ここでは受信済み event の確認だけを行います。")
      expect(text).to include("差分同期本体や購読作成・更新は後続 issue の範囲です。")
    end

    it "keeps existing webhook event rows and hides the empty state when events exist" do
      sign_in_as(admin_user)
      source = create_google_drive_source
      ExternalFolderSyncWebhookEvent.create!(
        external_folder_sync_source: source,
        provider: :google_drive,
        status: :received,
        received_at: Time.zone.parse("2026-01-16 10:15"),
        event_key: "drive-event-1",
        headers_json: { "X_GOOG_MESSAGE_NUMBER" => "42" },
        payload_json: { "resourceState" => "update" }
      )

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      text = webhook_events_card_text
      expect(text).to include("drive-event-1")
      expect(text).to include("42")
      expect(text).not_to include("まだ変更通知イベントは受信していません。")
    end
  end
end
