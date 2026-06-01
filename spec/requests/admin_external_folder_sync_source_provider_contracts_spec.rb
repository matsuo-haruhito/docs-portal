require "rails_helper"

RSpec.describe "Admin external folder sync source provider contracts", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def create_google_drive_source(name: "Drive source", auth_type: :service_account)
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type:,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: { client_email: "sync@example.com" }.to_json,
      provider_metadata: {}
    )
  end

  def create_microsoft_graph_source(name: "SharePoint source")
    create(:microsoft_graph_connection, project:, enabled: true)

    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :microsoft_graph,
      auth_type: :microsoft_graph_connection,
      name:,
      folder_url: "https://contoso.sharepoint.com/:f:/s/#{name.parameterize}/ExampleFolder",
      external_folder_id: "item-#{name.parameterize}",
      external_folder_path: "Shared Documents/#{name}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {
        "drive_id" => "drive-#{name.parameterize}",
        "folder_item_id" => "item-#{name.parameterize}",
        "folder_path" => "Shared Documents/#{name}",
        "site_id" => "site-#{name.parameterize}"
      }
    )
  end

  describe "GET /admin/external_folder_sync_sources" do
    it "ignores unsupported review filters while preserving search" do
      sign_in_as(admin_user)
      create_google_drive_source(name: "Drive policies")
      graph_source = create_microsoft_graph_source(name: "SharePoint policies")

      get admin_external_folder_sync_sources_path, params: { review: "archived", q: "sharepoint" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(graph_source.name)
      expect(response.body).to include("検索: sharepoint")
      expect(response.body).not_to include("Drive policies")
    end
  end

  describe "GET /admin/external_folder_sync_sources/:public_id" do
    it "keeps Google Drive operation surfaces separate from Microsoft Graph metadata-only surfaces" do
      sign_in_as(admin_user)
      graph_source = create_microsoft_graph_source
      google_source = create_google_drive_source

      get admin_external_folder_sync_source_path(graph_source)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drive ID")
      expect(response.body).to include("Folder item ID")
      expect(response.body).to include("保存済み metadata と今後の拡張")
      expect(response.body).to include("差分同期本体と変更通知は後続 issue で対応予定")
      expect(response.body).not_to include("同期プレビュー")
      expect(response.body).not_to include("変更通知の購読")

      get admin_external_folder_sync_source_path(google_source)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("同期プレビュー")
      expect(response.body).to include("同期する")
      expect(response.body).to include("変更通知の購読")
      expect(response.body).not_to include("保存済み metadata と今後の拡張")
    end
  end

  describe "provider-guarded runtime actions" do
    let(:graph_source) { create_microsoft_graph_source }
    let(:return_to) { admin_external_folder_sync_sources_path(review: "microsoft_graph", q: "sharepoint") }

    it "blocks Microsoft Graph dry-run before invoking the sync runner" do
      sign_in_as(admin_user)
      expect(ExternalFolderSync::Runner).not_to receive(:new)

      post dry_run_admin_external_folder_sync_source_path(graph_source), params: { return_to: return_to }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(graph_source, return_to: return_to))
    end

    it "blocks Microsoft Graph apply before invoking the sync runner and sanitizes unsafe return_to" do
      sign_in_as(admin_user)
      expect(ExternalFolderSync::Runner).not_to receive(:new)

      post apply_admin_external_folder_sync_source_path(graph_source), params: { return_to: "https://example.com/admin" }

      expect(response).to redirect_to(
        admin_external_folder_sync_source_path(graph_source, return_to: admin_external_folder_sync_sources_path)
      )
    end

    it "blocks Microsoft Graph enqueue before scheduling a background job" do
      sign_in_as(admin_user)
      expect(ExternalFolderSyncJob).not_to receive(:perform_later)

      post enqueue_admin_external_folder_sync_source_path(graph_source), params: { return_to: return_to }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(graph_source, return_to: return_to))
    end

    it "blocks Microsoft Graph subscriptions before creating a Google Drive subscription manager" do
      sign_in_as(admin_user)
      expect(ExternalFolderSync::GoogleDriveSubscriptionManager).not_to receive(:new)

      post subscribe_admin_external_folder_sync_source_path(graph_source), params: { return_to: return_to }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(graph_source, return_to: return_to))
    end

    it "allows Google Drive apply through the existing runner boundary" do
      sign_in_as(admin_user)
      google_source = create_google_drive_source
      run = instance_double(ExternalFolderSyncRun, items_scanned_count: 4)
      runner = instance_double(ExternalFolderSync::Runner, call: run)

      expect(ExternalFolderSync::Runner).to receive(:new).with(
        source: google_source,
        mode: :apply,
        actor: admin_user
      ).and_return(runner)

      post apply_admin_external_folder_sync_source_path(google_source), params: { return_to: admin_external_folder_sync_sources_path(review: "google_drive") }

      expect(response).to redirect_to(
        admin_external_folder_sync_source_path(google_source, return_to: admin_external_folder_sync_sources_path(review: "google_drive"))
      )
    end
  end
end
