require "rails_helper"

RSpec.describe "Admin external folder sync filter copy", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_google_drive_source(name:, enabled: true, last_error_message: nil)
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

  def create_microsoft_graph_source(name:)
    graph_project = create(:project, code: "SYNC002", name: "Graph Project")
    create(:microsoft_graph_connection, project: graph_project, enabled: true)

    ExternalFolderSyncSource.create!(
      project: graph_project,
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

  it "uses user-facing review and provider labels without changing filter links" do
    sign_in_as(admin_user)

    warning_source = create_google_drive_source(name: "Warning source")
    create_google_drive_source(name: "Error source", last_error_message: "latest sync failed")
    create_google_drive_source(name: "Disabled source", enabled: false)
    create_microsoft_graph_source(name: "SharePoint source")
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: warning_source,
      status: :completed,
      mode: :dry_run,
      started_at: Time.current,
      summary_json: { "conflict_warnings_count" => 2 }
    )

    get admin_external_folder_sync_sources_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("警告あり (1)")
    expect(page_text).to include("エラーあり (1)")
    expect(page_text).to include("警告・エラー・無効の同期元を先に確認")
    expect(page_text).to include("メタデータ確認のみ")
    expect(page_text).to include("drive_id / folder_path")

    expect(parsed_html.at_css(%(a[href="#{admin_external_folder_sync_sources_path(review: :warnings)}"]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{admin_external_folder_sync_sources_path(review: :errors)}"]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{admin_external_folder_sync_sources_path(review: :microsoft_graph)}"]))).to be_present
  end

  it "keeps selected and empty-state labels readable for review filters" do
    sign_in_as(admin_user)

    create_google_drive_source(name: "Clean source")

    get admin_external_folder_sync_sources_path(review: "warnings")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("現在の絞り込み: 警告あり")
    expect(page_text).to include("警告・エラー・無効のいずれかで 0 件の場合")
  end
end
