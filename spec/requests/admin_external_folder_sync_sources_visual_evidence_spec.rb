require "rails_helper"

RSpec.describe "Admin external folder sync source visual evidence", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def row_text_for(source_name)
    row = parsed_html.css("tbody tr").find { |node| node.text.include?(source_name) }

    expect(row).to be_present
    row.text.squish
  end

  def create_google_drive_source(name:, last_error_message: nil)
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
      enabled: true,
      auth_config: {}.to_json,
      last_error_message:
    )
  end

  def create_microsoft_graph_source(name:, last_error_message: nil)
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
      last_error_message:,
      provider_metadata: {
        "drive_id" => "drive-#{name.parameterize}",
        "folder_item_id" => "item-#{name.parameterize}",
        "folder_path" => "Shared Documents/#{name}"
      }
    )
  end

  def create_warning_run(source)
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: source,
      status: :partial,
      mode: :dry_run,
      started_at: Time.zone.local(2026, 6, 27, 8, 0, 0),
      error_message: "Authorization: Bearer run-secret failed from /Users/alice/private/source.md",
      summary_json: {
        "conflict_warnings_count" => 2,
        "blocked_by_conflict_warnings" => true
      }
    )
  end

  it "keeps provider support, latest run, warning, and latest error cues readable in the index state" do
    sign_in_as(admin_user)
    google_source = create_google_drive_source(name: "Google Drive policies")
    graph_source = create_microsoft_graph_source(
      name: "SharePoint metadata",
      last_error_message: "metadata lookup failed token=graph-secret /home/alice/private/source.md"
    )
    create_warning_run(google_source)

    get admin_external_folder_sync_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最新安全判定")
    expect(response.body).to include("競合・重複警告")
    expect(response.body).to include("最新エラー")
    expect(response.body).to include("Google Drive は dry-run / apply で同期実行できます。")
    expect(response.body).to include("SharePoint / OneDrive はメタデータ確認のみ")

    google_row = row_text_for(google_source.name)
    expect(google_row).to include("Google Drive")
    expect(google_row).to include("同期実行対象")
    expect(google_row).to include("dry-run / apply 可能")
    expect(google_row).to include("警告あり停止")
    expect(google_row).to include("直近run:")
    expect(google_row).to include("同期プレビュー")
    expect(google_row).to include("一部失敗")
    expect(google_row).to include("2")
    expect(google_row).to include("由来: 直近run")

    graph_row = row_text_for(graph_source.name)
    expect(graph_row).to include("SharePoint / OneDrive")
    expect(graph_row).to include("メタデータ確認のみ")
    expect(graph_row).to include("dry-run / apply 未対応")
    expect(graph_row).to include("直近runなし")
    expect(graph_row).to include("由来: 同期元metadata")

    page_text = parsed_html.text.squish
    expect(page_text).to include("[masked]")
    expect(page_text).to include("[path hidden]")
    expect(page_text).not_to include("run-secret")
    expect(page_text).not_to include("graph-secret")
  end

  it "keeps warning, error, and provider filters from mixing support boundaries" do
    sign_in_as(admin_user)
    google_source = create_google_drive_source(name: "Google Drive policies")
    graph_source = create_microsoft_graph_source(
      name: "SharePoint metadata",
      last_error_message: "metadata lookup failed token=graph-secret"
    )
    create_warning_run(google_source)

    get admin_external_folder_sync_sources_path, params: { review: "warnings" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(google_source.name)
    expect(response.body).not_to include(graph_source.name)
    expect(response.body).to include("現在の絞り込み: warning あり")
    expect(response.body).to include("1 / 2 件を表示しています。")

    get admin_external_folder_sync_sources_path, params: { review: "errors" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(google_source.name)
    expect(response.body).to include(graph_source.name)
    expect(response.body).to include("現在の絞り込み: エラーあり")
    expect(response.body).to include("2 / 2 件を表示しています。")

    get admin_external_folder_sync_sources_path, params: { review: "microsoft_graph" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(graph_source.name)
    expect(response.body).not_to include(google_source.name)
    expect(response.body).to include("現在の絞り込み: SharePoint / OneDrive")
    graph_row = row_text_for(graph_source.name)
    expect(graph_row).to include("メタデータ確認のみ")
    expect(graph_row).to include("dry-run / apply 未対応")
    expect(graph_row).not_to include("同期実行対象")
  end
end
