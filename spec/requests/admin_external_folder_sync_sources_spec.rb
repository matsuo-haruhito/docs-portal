require "rails_helper"

RSpec.describe "Admin external folder sync sources", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_google_drive_source(project:, name:, enabled: true, last_error_message: nil)
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
      auth_config: {}.to_json,
      last_error_message:
    )
  end

  def create_microsoft_graph_source(project:, name:)
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
        "folder_path" => "Shared Documents/#{name}"
      }
    )
  end

  describe "GET /admin/external_folder_sync_sources" do
    it "renders review filters for warnings, errors, disabled, and provider lanes" do
      sign_in_as(admin_user)
      warning_source = create_google_drive_source(project:, name: "Warning source")
      create_google_drive_source(project:, name: "Error source", last_error_message: "latest sync failed")
      create_google_drive_source(project:, name: "Disabled source", enabled: false)
      graph_project = create(:project, code: "SYNC002", name: "Graph Project")
      create_microsoft_graph_source(project: graph_project, name: "SharePoint source")
      ExternalFolderSyncRun.create!(
        external_folder_sync_source: warning_source,
        status: :completed,
        mode: :dry_run,
        started_at: Time.current,
        summary_json: { "conflict_warnings_count" => 2 }
      )

      get admin_external_folder_sync_sources_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("一覧の絞り込み")
      expect(response.body).to include("warning あり (1)")
      expect(response.body).to include("error あり (1)")
      expect(response.body).to include("無効 (1)")
      expect(response.body).to include("Google Drive (3)")
      expect(response.body).to include("SharePoint / OneDrive (1)")
      expect(response.body).to include("metadata-only")
    end

    it "filters the table to warning sources only" do
      sign_in_as(admin_user)
      warning_source = create_google_drive_source(project:, name: "Warning source")
      create_google_drive_source(project:, name: "Error source", last_error_message: "latest sync failed")
      create_google_drive_source(project:, name: "Disabled source", enabled: false)
      graph_project = create(:project, code: "SYNC002", name: "Graph Project")
      create_microsoft_graph_source(project: graph_project, name: "SharePoint source")
      ExternalFolderSyncRun.create!(
        external_folder_sync_source: warning_source,
        status: :completed,
        mode: :dry_run,
        started_at: Time.current,
        summary_json: { "conflict_warnings_count" => 2 }
      )

      get admin_external_folder_sync_sources_path, params: { review: "warnings" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(warning_source.name)
      expect(response.body).not_to include("Error source")
      expect(response.body).not_to include("Disabled source")
      expect(response.body).not_to include("SharePoint source")
      expect(response.body).to include("現在の絞り込み")
      expect(response.body).to include("1 / 4 件を表示しています。")
    end

    it "filters the table to SharePoint / OneDrive sources only" do
      sign_in_as(admin_user)
      create_google_drive_source(project:, name: "Warning source")
      create_google_drive_source(project:, name: "Error source", last_error_message: "latest sync failed")
      create_google_drive_source(project:, name: "Disabled source", enabled: false)
      graph_project = create(:project, code: "SYNC002", name: "Graph Project")
      graph_source = create_microsoft_graph_source(project: graph_project, name: "SharePoint source")

      get admin_external_folder_sync_sources_path, params: { review: "microsoft_graph" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(graph_source.name)
      expect(response.body).not_to include("Warning source")
      expect(response.body).not_to include("Error source")
      expect(response.body).not_to include("Disabled source")
      expect(response.body).to include("1 / 4 件を表示しています。")
      reset_link = parsed_html.at_css(%(a[href="#{admin_external_folder_sync_sources_path}"]))
      expect(reset_link).to be_present
    end
  end

  describe "POST /admin/external_folder_sync_sources" do
    let!(:graph_connection) { create(:microsoft_graph_connection, project:, enabled: true) }

    let(:params) do
      {
        external_folder_sync_source: {
          project_id: project.id,
          provider: "microsoft_graph",
          auth_type: "microsoft_graph_connection",
          name: "SharePoint docs",
          folder_url: "https://contoso.sharepoint.com/:f:/s/TeamDocs/ExampleFolder",
          external_folder_path: "",
          sync_direction: "external_to_portal",
          conflict_policy: "manual",
          enabled: "true",
          auth_config: ""
        }
      }
    end

    it "resolves and saves Microsoft Graph folder metadata" do
      sign_in_as(admin_user)
      resolver = instance_double(
        ExternalFolderSync::MicrosoftGraphFolderResolver,
        resolve: {
          drive_id: "drive-123",
          folder_item_id: "item-456",
          folder_path: "Shared Documents/Policies",
          site_id: "site-789"
        }
      )
      allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)

      expect do
        post admin_external_folder_sync_sources_path, params: params
      end.to change(ExternalFolderSyncSource, :count).by(1)

      source = ExternalFolderSyncSource.order(:id).last
      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(source.provider).to eq("microsoft_graph")
      expect(source.auth_type).to eq("microsoft_graph_connection")
      expect(source.external_folder_id).to eq("item-456")
      expect(source.external_folder_path).to eq("Shared Documents/Policies")
      expect(source.provider_metadata).to include(
        "drive_id" => "drive-123",
        "folder_item_id" => "item-456",
        "folder_path" => "Shared Documents/Policies",
        "site_id" => "site-789"
      )
      expect(source.auth_config).to eq("{}")

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drive ID")
      expect(response.body).to include("drive-123")
      expect(response.body).to include("Folder item ID")
      expect(response.body).to include("item-456")
    end

    it "shows a resolver error without creating a source" do
      sign_in_as(admin_user)
      resolver = instance_double(ExternalFolderSync::MicrosoftGraphFolderResolver)
      allow(resolver).to receive(:resolve).and_raise(
        ExternalFolderSync::MicrosoftGraphFolderResolver::Error,
        "共有URLからフォルダ情報を解決できませんでした。共有URLを確認してください。"
      )
      allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)

      expect do
        post admin_external_folder_sync_sources_path, params: params
      end.not_to change(ExternalFolderSyncSource, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("共有URLからフォルダ情報を解決できませんでした")
    end
  end

  describe "POST /admin/external_folder_sync_sources/:id/dry_run" do
    it "blocks dry-run for Microsoft Graph metadata-only sources" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, enabled: true)
      source = ExternalFolderSyncSource.create!(
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

      post dry_run_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      follow_redirect!
      expect(response.body).to include("後続 issue で対応予定")
      expect(response.body).not_to include("同期プレビュー")
    end
  end
end
