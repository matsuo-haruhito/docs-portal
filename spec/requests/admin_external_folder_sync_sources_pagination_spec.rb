require "rails_helper"

RSpec.describe "Admin external folder sync source pagination", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def href_for(text)
    link = parsed_html.css("a").find { |node| node.text.strip == text }
    link&.[]("href")
  end

  def query_params_for(text)
    Rack::Utils.parse_nested_query(URI.parse(href_for(text)).query)
  end

  def create_google_drive_source(name:, project: nil, enabled: true, last_error_message: nil)
    target_project = project || self.project

    ExternalFolderSyncSource.create!(
      project: target_project,
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

  def create_microsoft_graph_source(name:, project:)
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

  def create_latest_run(source:, warnings_count: 0, error_message: nil, started_at: Time.current)
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: source,
      status: error_message.present? ? :failed : :completed,
      mode: :dry_run,
      started_at:,
      summary_json: { "conflict_warnings_count" => warnings_count },
      error_message:
    )
  end

  it "shows a bounded first page and preserves filters in the next link" do
    sign_in_as(admin_user)
    12.times { |index| create_google_drive_source(name: "Paged #{index.to_s.rjust(2, '0')}") }

    get admin_external_folder_sync_sources_path, params: { per_page: 5 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件一致 12 件中 1-5 件")
    expect(response.body).to include("1 / 3ページ")
    expect(response.body).to include("Paged 00")
    expect(response.body).to include("Paged 04")
    expect(response.body).not_to include("Paged 05")
    expect(query_params_for("次へ")).to include("page" => "2", "per_page" => "5")
  end

  it "returns to the current page from detail and edit links" do
    sign_in_as(admin_user)
    12.times { |index| create_google_drive_source(name: "Paged #{index.to_s.rjust(2, '0')}") }

    get admin_external_folder_sync_sources_path, params: { page: 2, per_page: 5 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件一致 12 件中 6-10 件")
    expect(response.body).to include("2 / 3ページ")
    expect(response.body).to include("Paged 05")
    expect(response.body).not_to include("Paged 04")
    expect(response.body).not_to include("Paged 10")

    detail_params = Rack::Utils.parse_nested_query(URI.parse(href_for("設定詳細")).query)
    edit_params = Rack::Utils.parse_nested_query(URI.parse(href_for("編集")).query)
    expected_return_to = admin_external_folder_sync_sources_path(page: 2, per_page: 5)
    expect(detail_params["return_to"]).to eq(expected_return_to)
    expect(edit_params["return_to"]).to eq(expected_return_to)
  end

  it "keeps q and provider filters while moving between pages" do
    sign_in_as(admin_user)
    5.times { |index| create_google_drive_source(name: "Finance drive #{index}") }
    create_google_drive_source(name: "Security drive")
    graph_project = create(:project, code: "GRAPH", name: "Finance Graph")
    create_microsoft_graph_source(name: "Finance graph", project: graph_project)

    get admin_external_folder_sync_sources_path, params: { review: "google_drive", q: "finance", per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在の絞り込み: Google Drive / 検索: finance")
    expect(response.body).to include("条件一致 5 件中 1-2 件")
    expect(response.body).to include("Finance drive 0")
    expect(response.body).to include("Finance drive 1")
    expect(response.body).not_to include("Finance graph")
    expect(query_params_for("次へ")).to include(
      "review" => "google_drive",
      "q" => "finance",
      "page" => "2",
      "per_page" => "2"
    )
  end

  it "applies pagination after latest-run warning filtering" do
    sign_in_as(admin_user)
    warning_sources = 3.times.map { |index| create_google_drive_source(name: "Warning #{index}") }
    clean_sources = 3.times.map { |index| create_google_drive_source(name: "Clean #{index}") }
    warning_sources.each { |source| create_latest_run(source:, warnings_count: 2) }
    clean_sources.each { |source| create_latest_run(source:, warnings_count: 0) }

    get admin_external_folder_sync_sources_path, params: { review: "warnings", page: 2, per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("warning あり (3)")
    expect(response.body).to include("条件一致 3 件中 3-3 件")
    expect(response.body).to include("2 / 2ページ")
    expect(response.body).to include("Warning 2")
    expect(response.body).not_to include("Warning 0")
    expect(response.body).not_to include("Clean 0")
    expect(query_params_for("前へ")).to include("review" => "warnings", "page" => "1", "per_page" => "2")
  end

  it "clamps invalid page and per_page values to the bounded range" do
    sign_in_as(admin_user)
    3.times { |index| create_google_drive_source(name: "Paged #{index.to_s.rjust(2, '0')}") }

    get admin_external_folder_sync_sources_path, params: { page: 99, per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件一致 3 件中 3-3 件")
    expect(response.body).to include("2 / 2ページ")
    expect(response.body).to include("Paged 02")
    expect(response.body).not_to include("Paged 00")
  end

  it "keeps the filtered empty state distinct from an unregistered empty state" do
    sign_in_as(admin_user)
    create_google_drive_source(name: "Finance drive")

    get admin_external_folder_sync_sources_path, params: { q: "missing-source", page: "bad", per_page: "bad" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在の検索 / 絞り込みに一致する外部フォルダ同期設定はありません。")
    expect(response.body).to include("検索: missing-source")
    expect(response.body).not_to include("まだ外部フォルダ同期設定は登録されていません。")
    expect(href_for("次へ")).to be_nil
  end
end
