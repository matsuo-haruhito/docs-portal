require "rails_helper"

RSpec.describe "Admin external folder sync source filters and return_to", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def href_for(text)
    link = parsed_html.css("a").find { |node| node.text.strip == text }
    link&.[]("href")
  end

  def form_action_for_button(text)
    form = parsed_html.css("form").find do |node|
      node.css("button, input[type='submit']").any? do |button|
        button.text.strip == text || button["value"] == text
      end
    end
    form&.[]("action")
  end

  def create_google_drive_source(project:, name:, enabled: true)
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :service_account,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      external_folder_path: "Google Drive/#{name}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled:,
      auth_config: { client_email: "sync@example.com" }.to_json,
      provider_metadata: {}
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
    it "keeps review and search filters in detail, edit, and delete links" do
      sign_in_as(admin_user)
      graph_project = create(:project, code: "SYNC002", name: "Graph Project")
      source = create_microsoft_graph_source(project: graph_project, name: "Policies SharePoint")
      create_google_drive_source(project:, name: "Policies Google Drive")
      return_to = "#{admin_external_folder_sync_sources_path}?review=microsoft_graph&q=policies"

      get admin_external_folder_sync_sources_path, params: { review: "microsoft_graph", q: "policies" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(source.name)
      expect(response.body).not_to include("Policies Google Drive")
      expect(response.body).to include("現在の絞り込み: SharePoint / OneDrive / 検索: policies")
      expect(href_for("設定詳細")).to eq(admin_external_folder_sync_source_path(source, return_to: return_to))
      expect(href_for("編集")).to eq(edit_admin_external_folder_sync_source_path(source, return_to: return_to))
      expect(form_action_for_button("削除")).to eq(admin_external_folder_sync_source_path(source, return_to: return_to))
    end

    it "treats unsupported review values as all while keeping the search query" do
      sign_in_as(admin_user)
      finance_source = create_google_drive_source(project:, name: "Finance Drive")
      create_google_drive_source(project:, name: "Operations Drive")

      get admin_external_folder_sync_sources_path, params: { review: "drop_table", q: "finance" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(finance_source.name)
      expect(response.body).not_to include("Operations Drive")
      expect(response.body).to include("現在の絞り込み: 検索: finance")
      expect(parsed_html.text).not_to include("drop_table")
    end

    it "keeps provider filters within the current Google Drive and SharePoint / OneDrive boundary" do
      sign_in_as(admin_user)
      drive_source = create_google_drive_source(project:, name: "Finance Drive")
      graph_project = create(:project, code: "SYNC002", name: "Graph Project")
      graph_source = create_microsoft_graph_source(project: graph_project, name: "Policies SharePoint")

      get admin_external_folder_sync_sources_path, params: { review: "google_drive", q: "finance" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(drive_source.name)
      expect(response.body).to include("同期実行対象")
      expect(response.body).not_to include(graph_source.name)

      get admin_external_folder_sync_sources_path, params: { review: "microsoft_graph", q: "policies" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(graph_source.name)
      expect(response.body).to include("メタデータ確認のみ")
      expect(response.body).not_to include(drive_source.name)
    end
  end

  describe "return_to safety" do
    it "falls protocol-relative return_to values back to the sync source list" do
      sign_in_as(admin_user)
      source = create_google_drive_source(project:, name: "Drive source")

      get admin_external_folder_sync_source_path(source), params: { return_to: "//evil.example/admin" }

      expect(response).to have_http_status(:ok)
      expect(href_for("一覧へ戻る")).to eq(admin_external_folder_sync_sources_path)
      expect(href_for("編集")).to eq(edit_admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
    end

    it "falls absolute return_to values back to the sync source list after destroy" do
      sign_in_as(admin_user)
      source = create_google_drive_source(project:, name: "Drive source")

      delete admin_external_folder_sync_source_path(source), params: { return_to: "https://evil.example/admin" }

      expect(response).to redirect_to(admin_external_folder_sync_sources_path)
      expect(ExternalFolderSyncSource.exists?(source.id)).to be(false)
    end
  end
end
