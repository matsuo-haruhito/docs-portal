require "rails_helper"

RSpec.describe "Admin external folder sync source filtered empty cues", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_google_drive_source(name:, enabled: true)
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled:,
      auth_config: {}.to_json
    )
  end

  describe "GET /admin/external_folder_sync_sources" do
    it "shows a search cue near the filtered empty state without mixing the unregistered state" do
      sign_in_as(admin_user)
      create_google_drive_source(name: "Finance policies")

      get admin_external_folder_sync_sources_path, params: { q: "missing-source" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("現在の検索 / 絞り込みに一致する外部フォルダ同期設定はありません。")
      expect(response.body).to include("検索: missing-source")
      expect(response.body).to include("検索語は同期設定名、案件名 / code、外部フォルダ ID / path の断片で短くして確認してください。")
      expect(response.body).to include("すべて解除")
      expect(response.body).not_to include("まだ外部フォルダ同期設定は登録されていません。")
    end

    it "shows the review filter cue when a review-priority filter has no matches" do
      sign_in_as(admin_user)
      create_google_drive_source(name: "Clean source")

      get admin_external_folder_sync_sources_path, params: { review: "warnings" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("現在の絞り込み: 警告あり")
      expect(response.body).to include("警告・エラー・無効のいずれかで 0 件の場合は、別のレビュー優先 filter または「すべて」に戻して確認してください。")
      expect(parsed_html.css("a").map { |node| node.text.strip }).to include("すべて解除")
    end

    it "keeps the provider support boundary visible when the provider filter has no matches" do
      sign_in_as(admin_user)
      create_google_drive_source(name: "Drive source")

      get admin_external_folder_sync_sources_path, params: { review: "microsoft_graph" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("現在の絞り込み: SharePoint / OneDrive")
      expect(response.body).to include("SharePoint / OneDrive はメタデータ確認のみとして drive_id / folder_path など保存情報を確認します。")
      expect(response.body).to include("同期実行対象を探すときは Google Drive 側も確認してください。")
      expect(parsed_html.css("a").map { |node| node.text.strip }).to include("すべて解除")
    end

    it "does not show filtered empty cues when no sync source is registered" do
      sign_in_as(admin_user)

      get admin_external_folder_sync_sources_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("まだ外部フォルダ同期設定は登録されていません。")
      expect(response.body).not_to include("別のレビュー優先 filter")
      expect(response.body).not_to include("検索語は同期設定名")
    end
  end
end
