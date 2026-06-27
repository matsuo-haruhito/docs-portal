require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection pagination", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_href(text)
    parsed_html.css("a").find { |link| link.text.squish == text }&.[]("href")
  end

  def create_connection(number, name_prefix:, enabled: true)
    project = create(
      :project,
      code: format("MGP%03d", number),
      name: "Microsoft Graph Page #{number}"
    )

    create(
      :microsoft_graph_connection,
      project:,
      name: format("#{name_prefix} %03d", number),
      enabled:,
      preview_folder_path: "Shared Documents/#{name_prefix} #{number}"
    )
  end

  def create_duplicate_project_connections(number)
    project = create(
      :project,
      code: format("MGD%03d", number),
      name: "Microsoft Graph Duplicate #{number}"
    )
    first = create(:microsoft_graph_connection, project:, name: format("Cleanup %03d A", number), enabled: true)
    second = create(:microsoft_graph_connection, project:, name: format("Cleanup %03d B", number), enabled: false)
    second.update_column(:enabled, true)

    [first, second]
  end

  it "keeps the search query and preview filter while moving to the next page" do
    sign_in_as(admin_user)
    (1..51).each do |number|
      create_connection(number, name_prefix: "Archive page", enabled: false)
    end
    create_connection(900, name_prefix: "Unrelated page", enabled: false)

    get admin_microsoft_graph_connections_path, params: { q: "Archive", preview_usage: "disabled", page: "2" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Archive page 051")
    expect(response.body).not_to include("Archive page 001")
    expect(response.body).not_to include("Unrelated page 900")
    expect(response.body).to include("現在の絞り込み: 無効 / previewでは未使用 / 検索: Archive")
    expect(response.body).to include("表示範囲: 51-51件 / 条件一致 51件")
    expect(response.body).to include("2ページ目 / 50件上限")
    expect(response.body).to include("Microsoft Graph接続一覧の表示設定")
    expect(link_href("前の50件")).to eq(admin_microsoft_graph_connections_path(q: "Archive", preview_usage: "disabled", page: 1))
    expect(link_href("次の50件")).to be_nil
  end

  it "keeps duplicate cleanup filtering while moving across pages" do
    sign_in_as(admin_user)
    (1..26).each { |number| create_duplicate_project_connections(number) }
    create_connection(900, name_prefix: "Cleanup unrelated", enabled: false)

    get admin_microsoft_graph_connections_path, params: { duplicate_only: "1", q: "Cleanup", page: "2" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cleanup 026 A")
    expect(response.body).to include("Cleanup 026 B")
    expect(response.body).not_to include("Cleanup 001 A")
    expect(response.body).not_to include("Cleanup unrelated 900")
    expect(response.body).to include("現在の絞り込み: 要整理案件のみ / 検索: Cleanup")
    expect(response.body).to include("表示範囲: 51-52件 / 条件一致 52件")
    expect(link_href("前の50件")).to eq(admin_microsoft_graph_connections_path(q: "Cleanup", duplicate_only: "1", page: 1))
  end

  it "falls back to the first page for unsupported page values" do
    sign_in_as(admin_user)
    create_connection(1, name_prefix: "Fallback page")
    create_connection(2, name_prefix: "Fallback page")

    get admin_microsoft_graph_connections_path, params: { page: "99" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Fallback page 001")
    expect(response.body).to include("Fallback page 002")
    expect(response.body).to include("表示範囲: 1-2件 / 条件一致 2件")
    expect(response.body).to include("1ページ目 / 50件上限")
    expect(link_href("前の50件")).to be_nil
    expect(link_href("次の50件")).to be_nil
  end
end
