require "rails_helper"

RSpec.describe "Admin external folder sync source metadata recheck", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_google_drive_source
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :service_account,
      name: "Drive docs",
      folder_url: "https://drive.google.com/drive/folders/folder-123",
      external_folder_id: "folder-123",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: { client_email: "sync@example.com" }.to_json,
      provider_metadata: {}
    )
  end

  def create_microsoft_graph_source
    create(:microsoft_graph_connection, project:, enabled: true)

    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :microsoft_graph,
      auth_type: :microsoft_graph_connection,
      name: "SharePoint docs",
      folder_url: "https://contoso.sharepoint.com/:f:/s/TeamDocs/ExampleFolder",
      external_folder_id: "item-456",
      external_folder_path: "Shared Documents/Policies",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {
        "drive_id" => "drive-123",
        "folder_item_id" => "item-456",
        "folder_path" => "Shared Documents/Policies",
        "site_id" => "site-789"
      }
    )
  end

  def stub_graph_resolution(result)
    resolver = instance_double(ExternalFolderSync::MicrosoftGraphFolderResolver, resolve: result)
    allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)
    resolver
  end

  describe "GET /admin/external_folder_sync_sources/:public_id" do
    it "shows the recheck action only for Microsoft Graph metadata-only sources" do
      sign_in_as(admin_user)
      graph_source = create_microsoft_graph_source
      google_source = create_google_drive_source

      get admin_external_folder_sync_source_path(graph_source)

      expect(response).to have_http_status(:ok)
      recheck_links = parsed_html.css("a").select { |node| node.text.strip == "保存済み metadata を再確認" }
      expect(recheck_links).not_to be_empty
      expect(recheck_links.map { |node| node["href"] }.uniq).to eq([
        recheck_metadata_admin_external_folder_sync_source_path(graph_source, return_to: admin_external_folder_sync_sources_path)
      ])
      expect(response.body).to include("同期本体を実行せず現在の Microsoft Graph 解決結果との差分だけを確認します")
      expect(response.body).not_to include("保存済み metadata 再確認結果")

      get admin_external_folder_sync_source_path(google_source)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("保存済み metadata を再確認")
    end
  end

  describe "POST /admin/external_folder_sync_sources/:public_id/recheck_metadata" do
    it "reports that saved Microsoft Graph metadata still matches" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source
      stub_graph_resolution(
        drive_id: "drive-123",
        folder_item_id: "item-456",
        folder_path: "Shared Documents/Policies",
        site_id: "site-789"
      )

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("保存済み metadata を再確認しました")
      expect(response.body).to include("現在の Microsoft Graph 解決結果と一致しています")
      expect(response.body).to include("保存済み metadata 再確認結果")
      expect(response.body).to include("一致: Drive ID / Folder item ID / Folder path / Site ID")
      expect(response.body).not_to include("差分あり:")
    end

    it "reports metadata differences without saving the resolved values" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source
      stub_graph_resolution(
        drive_id: "drive-999",
        folder_item_id: "item-999",
        folder_path: "Shared Documents/Renamed Policies",
        site_id: "site-789"
      )

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      expect(source.reload.external_folder_id).to eq("item-456")
      expect(source.external_folder_path).to eq("Shared Documents/Policies")
      expect(source.provider_metadata).to include(
        "drive_id" => "drive-123",
        "folder_item_id" => "item-456",
        "folder_path" => "Shared Documents/Policies",
        "site_id" => "site-789"
      )

      follow_redirect!
      expect(response.body).to include("差分があります: Drive ID / Folder item ID / Folder path")
      expect(response.body).to include("保存済み値は変更していません")
      expect(response.body).to include("設定を編集して保存し直してください")
      expect(response.body).to include("保存済み metadata 再確認結果")
      expect(response.body).to include("差分あり: Drive ID / Folder item ID / Folder path")
      expect(response.body).to include("一致: Site ID")
      expect(response.body).not_to include("drive-999")
      expect(response.body).not_to include("item-999")
      expect(response.body).not_to include("Shared Documents/Renamed Policies")
    end

    it "shows bounded resolver errors without exposing raw Graph payloads" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source
      saved_external_folder_id = source.external_folder_id
      saved_external_folder_path = source.external_folder_path
      saved_provider_metadata = source.provider_metadata.deep_dup
      unsafe_error_message = <<~MESSAGE.squish
        Microsoft Graph returned 403 Authorization: Bearer secret-access-token
        client_secret=super-secret-value {"error":{"message":"rawGraphPayload"}}
      MESSAGE
      resolver = instance_double(ExternalFolderSync::MicrosoftGraphFolderResolver)
      allow(resolver).to receive(:resolve).and_raise(
        ExternalFolderSync::MicrosoftGraphFolderResolver::Error,
        unsafe_error_message
      )
      allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      expect(source.reload.external_folder_id).to eq(saved_external_folder_id)
      expect(source.external_folder_path).to eq(saved_external_folder_path)
      expect(source.provider_metadata).to eq(saved_provider_metadata)

      follow_redirect!
      expect(response.body).to include("保存済み metadata を再確認できませんでした")
      expect(response.body).to include("Microsoft Graph接続・共有URL・権限を確認してください")
      expect(response.body).not_to include("Authorization: Bearer")
      expect(response.body).not_to include("secret-access-token")
      expect(response.body).not_to include("client_secret")
      expect(response.body).not_to include("super-secret-value")
      expect(response.body).not_to include("rawGraphPayload")
      expect(response.body).not_to include("保存済み metadata 再確認結果")
    end

    it "rejects recheck for Google Drive sources without enabling Microsoft Graph runtime operations" do
      sign_in_as(admin_user)
      source = create_google_drive_source

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("SharePoint / OneDrive の metadata-only source で利用できます")
      expect(response.body).to include("同期プレビュー")
      expect(response.body).not_to include("SharePoint / OneDrive の差分同期と変更通知は後続 issue")
      expect(response.body).not_to include("保存済み metadata 再確認結果")
    end
  end
end
