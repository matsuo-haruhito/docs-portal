require "rails_helper"
require "uri"

RSpec.describe "Admin external folder sync source pagination cues", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def query_params_for(link)
    uri = URI.parse(link.fetch("href"))

    expect(uri.path).to eq(admin_external_folder_sync_sources_path)

    Rack::Utils.parse_nested_query(uri.query)
  end

  def create_google_drive_source(name:)
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
      auth_config: {}.to_json
    )
  end

  it "labels pagination links with the destination page and preserved filters" do
    sign_in_as(admin_user)
    create_google_drive_source(name: "Finance policies")
    create_google_drive_source(name: "Finance procedures")
    create_google_drive_source(name: "Finance reports")

    get admin_external_folder_sync_sources_path, params: { review: "google_drive", q: "finance", per_page: 1, page: 2 }

    expect(response).to have_http_status(:ok)

    nav = parsed_html.at_css(%(nav.pagination[aria-label="外部フォルダ同期設定一覧のページ移動"]))
    expect(nav).to be_present

    previous_link = nav.at_css(%(a[rel="prev"]))
    next_link = nav.at_css(%(a[rel="next"]))

    expect(previous_link.text.strip).to eq("前へ")
    expect(previous_link["aria-label"]).to include("前のページへ移動（1 / 3ページ")
    expect(previous_link["aria-label"]).to include("現在の絞り込み（Google Drive / 検索: finance）を維持")
    expect(previous_link["title"]).to eq(previous_link["aria-label"])
    expect(query_params_for(previous_link)).to include(
      "page" => "1",
      "per_page" => "1",
      "q" => "finance",
      "review" => "google_drive"
    )

    expect(next_link.text.strip).to eq("次へ")
    expect(next_link["aria-label"]).to include("次のページへ移動（3 / 3ページ")
    expect(next_link["aria-label"]).to include("現在の絞り込み（Google Drive / 検索: finance）を維持")
    expect(next_link["title"]).to eq(next_link["aria-label"])
    expect(query_params_for(next_link)).to include(
      "page" => "3",
      "per_page" => "1",
      "q" => "finance",
      "review" => "google_drive"
    )
  end
end
