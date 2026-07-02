require "rails_helper"

RSpec.describe "Admin external folder sync source items empty state", type: :request do
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

  def sync_items_card_text
    card = parsed_html.xpath("//h2[normalize-space()='同期アイテム']/ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' card ')][1]").first
    expect(card).to be_present
    card.text.squish
  end

  describe "GET /admin/external_folder_sync_sources/:public_id" do
    it "shows a read-only empty state when no sync items exist" do
      sign_in_as(admin_user)
      source = create_google_drive_source

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      text = sync_items_card_text
      expect(text).to include("同期アイテム")
      expect(text).to include("まだ同期アイテムはありません。")
      expect(text).to include("同期プレビューまたは同期を実行すると、外部フォルダ内のファイルとポータル文書の対応がここに表示されます。")
      expect(text).to include("詳細は上の同期履歴の「結果詳細」で確認してください。")
    end

    it "keeps existing item rows and hides the empty state when sync items exist" do
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
  end
end
