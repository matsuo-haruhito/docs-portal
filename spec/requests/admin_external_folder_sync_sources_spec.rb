require "rails_helper"

RSpec.describe "Admin external folder sync sources", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def href_for(text)
    link = parsed_html.css("a").find { |node| node.text.strip == text }
    link&.[]("href")
  end

  def hidden_field_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def table_preference_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  def create_google_drive_source(project:, name:, enabled: true, last_error_message: nil, auth_type: :oauth_user, auth_config: nil)
    auth_config ||= auth_type.to_sym == :service_account ? { client_email: "sync@example.com" }.to_json : {}.to_json

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
      enabled:,
      auth_config:,
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

    it "renders table preference editor and stable column keys" do
      sign_in_as(admin_user)
      create_google_drive_source(project:, name: "Drive source")

      get admin_external_folder_sync_sources_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("外部フォルダ同期設定一覧の表示設定")
      expect(response.body).to include("admin_external_folder_sync_sources")
      expect(table_preference_column_keys).to include(
        "project",
        "name",
        "provider",
        "external_folder_location",
        "status",
        "last_synced_at",
        "latest_safety",
        "warning_count",
        "latest_error",
        "actions"
      )
      expect(response.body).to include("folder-drive-source")
    end

    it "keeps table preferences visible with review filters and preserves return_to links" do
      sign_in_as(admin_user)
      warning_source = create_google_drive_source(project:, name: "Warning source")
      create_google_drive_source(project:, name: "Error source", last_error_message: "latest sync failed")
      ExternalFolderSyncRun.create!(
        external_folder_sync_source: warning_source,
        status: :completed,
        mode: :dry_run,
        started_at: Time.current,
        summary_json: { "conflict_warnings_count" => 2 }
      )
      return_to = admin_external_folder_sync_sources_path(review: "warnings")

      get admin_external_folder_sync_sources_path, params: { review: "warnings" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("外部フォルダ同期設定一覧の表示設定")
      expect(table_preference_column_keys).to include("external_folder_location", "latest_error", "actions")
      expect(response.body).to include(warning_source.name)
      expect(response.body).not_to include("Error source")
      expect(response.body).to include("現在の絞り込み")
      expect(response.body).to include("1 / 2 件を表示しています。")
      expect(href_for("設定詳細")).to eq(admin_external_folder_sync_source_path(warning_source, return_to: return_to))
      expect(href_for("編集")).to eq(edit_admin_external_folder_sync_source_path(warning_source, return_to: return_to))
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

    it "preserves the review filter in detail and edit links" do
      sign_in_as(admin_user)
      warning_source = create_google_drive_source(project:, name: "Warning source")
      ExternalFolderSyncRun.create!(
        external_folder_sync_source: warning_source,
        status: :completed,
        mode: :dry_run,
        started_at: Time.current,
        summary_json: { "conflict_warnings_count" => 2 }
      )
      return_to = admin_external_folder_sync_sources_path(review: "warnings")

      get admin_external_folder_sync_sources_path, params: { review: "warnings" }

      expect(href_for("設定詳細")).to eq(admin_external_folder_sync_source_path(warning_source, return_to: return_to))
      expect(href_for("編集")).to eq(edit_admin_external_folder_sync_source_path(warning_source, return_to: return_to))
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
      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      expect(response.location).to end_with("/admin/external_folder_sync_sources/#{source.public_id}?return_to=%2Fadmin%2Fexternal_folder_sync_sources")
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
      expect(response.body).to include("/admin/external_folder_sync_sources/#{source.public_id}/edit")
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

  describe "GET /admin/external_folder_sync_sources/:public_id" do
    it "returns 404 for numeric ids" do
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

      get admin_external_folder_sync_source_path(source.id)

      expect(response).to have_http_status(:not_found)
    end

    it "renders detail and edit back links with the review filter context" do
      sign_in_as(admin_user)
      graph_project = create(:project, code: "SYNC002", name: "Graph Project")
      source = create_microsoft_graph_source(project: graph_project, name: "SharePoint source")
      return_to = admin_external_folder_sync_sources_path(review: "microsoft_graph")

      get admin_external_folder_sync_source_path(source), params: { return_to: return_to }

      expect(response).to have_http_status(:ok)
      expect(href_for("一覧へ戻る")).to eq(return_to)
      expect(href_for("編集")).to eq(edit_admin_external_folder_sync_source_path(source, return_to: return_to))

      get edit_admin_external_folder_sync_source_path(source), params: { return_to: return_to }

      expect(response).to have_http_status(:ok)
      expect(hidden_field_value("return_to")).to eq(return_to)
      expect(href_for("詳細へ戻る")).to eq(admin_external_folder_sync_source_path(source, return_to: return_to))
    end
  end

  describe "PATCH /admin/external_folder_sync_sources/:public_id" do
    it "redirects back to the source detail with return_to preserved" do
      sign_in_as(admin_user)
      source = create_google_drive_source(project:, name: "Drive source", auth_type: :service_account)
      return_to = admin_external_folder_sync_sources_path(review: "google_drive")

      patch admin_external_folder_sync_source_path(source), params: {
        return_to: return_to,
        external_folder_sync_source: {
          project_id: project.id,
          provider: "google_drive",
          auth_type: "service_account",
          name: "Drive source updated",
          folder_url: source.folder_url,
          external_folder_path: "",
          sync_direction: "external_to_portal",
          conflict_policy: "manual",
          enabled: "true",
          auth_config: { client_email: "sync@example.com" }.to_json
        }
      }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: return_to))
      expect(source.reload.name).to eq("Drive source updated")
    end
  end

  describe "POST /admin/external_folder_sync_sources/:public_id/dry_run" do
    let!(:graph_connection) { create(:microsoft_graph_connection, project:, enabled: true) }
    let(:source) do
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

    it "blocks dry-run for Microsoft Graph metadata-only sources" do
      sign_in_as(admin_user)

      post dry_run_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("後続 issue で対応予定")
      expect(response.body).not_to include("同期プレビュー")
    end

    it "preserves return_to after a Google Drive dry run" do
      sign_in_as(admin_user)
      google_source = create_google_drive_source(project:, name: "Drive source", auth_type: :service_account)
      return_to = admin_external_folder_sync_sources_path(review: "google_drive")
      run = instance_double(ExternalFolderSyncRun, items_scanned_count: 3)
      runner = instance_double(ExternalFolderSync::Runner, call: run)
      allow(ExternalFolderSync::Runner).to receive(:new).and_return(runner)

      post dry_run_admin_external_folder_sync_source_path(google_source), params: { return_to: return_to }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(google_source, return_to: return_to))
    end

    it "returns 404 for numeric ids" do
      sign_in_as(admin_user)

      post dry_run_admin_external_folder_sync_source_path(source.id)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /admin/external_folder_sync_sources/:external_folder_sync_source_public_id/external_folder_sync_oauth_connection/new" do
    let(:source) do
      ExternalFolderSyncSource.create!(
        project:,
        created_by: admin_user,
        provider: :google_drive,
        auth_type: :oauth_user,
        name: "Drive docs",
        folder_url: "https://drive.google.com/drive/folders/folder-123",
        external_folder_id: "folder-123",
        sync_direction: :external_to_portal,
        conflict_policy: :manual,
        enabled: true,
        auth_config: {}.to_json,
        provider_metadata: {}
      )
    end

    it "resolves nested routes via public_id" do
      sign_in_as(admin_user)
      allow_any_instance_of(Admin::ExternalFolderSyncOauthConnectionsController)
        .to receive(:missing_google_oauth_env_keys).and_return(["GOOGLE_DRIVE_OAUTH_CLIENT_ID"])

      get new_admin_external_folder_sync_source_external_folder_sync_oauth_connection_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(response.location).to end_with("/admin/external_folder_sync_sources/#{source.public_id}")
    end

    it "returns 404 for numeric ids" do
      sign_in_as(admin_user)

      get new_admin_external_folder_sync_source_external_folder_sync_oauth_connection_path(source.id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
