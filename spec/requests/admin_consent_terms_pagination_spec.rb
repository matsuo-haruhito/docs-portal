require "rails_helper"
require "uri"

RSpec.describe "Admin consent term pagination", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def term_titles
    parsed_html.css('tbody tr td[data-rails-table-preferences-column-key="title"]').map { |cell| cell.text.squish }
  end

  def link_query(text)
    href = parsed_html.css("a").find { |link| link.text.squish == text }&.[]("href")
    return nil if href.blank?

    Rack::Utils.parse_nested_query(URI.parse(href).query)
  end

  def create_consent_term(number, title_prefix:, active: true, consent_scope: :project, requirement_timing: :first_view)
    create(
      :consent_term,
      title: format("#{title_prefix} %03d", number),
      version_label: format("v%03d", number),
      active:,
      consent_scope:,
      requirement_timing:
    )
  end

  it "keeps filters while moving across pages" do
    sign_in_as(admin_user)
    (1..26).each do |number|
      create_consent_term(
        number,
        title_prefix: "Archive Terms",
        active: false,
        consent_scope: :download,
        requirement_timing: :every_download
      )
    end
    create_consent_term(900, title_prefix: "Unrelated Terms", active: false, consent_scope: :download, requirement_timing: :every_download)

    get admin_consent_terms_path,
      params: {
        q: "Archive",
        active: "false",
        consent_scope: "download",
        requirement_timing: "every_download",
        page: "2",
        rails_table_preferences: { admin_consent_terms: { columns: ["title"] } }
      }

    expect(response).to have_http_status(:ok)
    expect(term_titles).to eq(["Archive Terms 026"])
    expect(page_text).to include("条件に一致する同意文面 26件中 26-26件を表示")
    expect(page_text).to include("検索: Archive")
    expect(page_text).to include("状態: 無効")
    expect(page_text).to include("同意文面一覧の表示設定")
    expect(link_query("前へ")).to include(
      "q" => "Archive",
      "active" => "false",
      "consent_scope" => "download",
      "requirement_timing" => "every_download",
      "per_page" => "25",
      "page" => "1"
    )
    expect(link_query("前へ")).not_to include("rails_table_preferences")
    expect(link_query("次へ")).to be_nil
  end

  it "uses the default page size and shows the last page range" do
    sign_in_as(admin_user)
    (1..26).each { |number| create_consent_term(number, title_prefix: "Default Terms") }

    get admin_consent_terms_path, params: { page: "2" }

    expect(response).to have_http_status(:ok)
    expect(term_titles).to eq(["Default Terms 026"])
    expect(page_text).to include("条件に一致する同意文面 26件中 26-26件を表示")
    expect(page_text).to include("1ページあたり25件まで表示します。per_page は最大100件です。")
    expect(link_query("前へ")).to include("per_page" => "25", "page" => "1")
    expect(link_query("次へ")).to be_nil
  end

  it "caps per_page at the configured maximum" do
    sign_in_as(admin_user)
    (1..101).each { |number| create_consent_term(number, title_prefix: "Capped Terms") }

    get admin_consent_terms_path, params: { per_page: "500", page: "2" }

    expect(response).to have_http_status(:ok)
    expect(term_titles).to eq(["Capped Terms 101"])
    expect(page_text).to include("条件に一致する同意文面 101件中 101-101件を表示")
    expect(page_text).to include("1ページあたり100件まで表示します。per_page は最大100件です。")
    expect(link_query("前へ")).to include("per_page" => "100", "page" => "1")
  end

  it "falls back safely for unsupported page and per_page values" do
    sign_in_as(admin_user)
    create_consent_term(1, title_prefix: "Fallback Terms")
    create_consent_term(2, title_prefix: "Fallback Terms")

    get admin_consent_terms_path, params: { per_page: "invalid", page: "99" }

    expect(response).to have_http_status(:ok)
    expect(term_titles).to eq(["Fallback Terms 001", "Fallback Terms 002"])
    expect(page_text).to include("条件に一致する同意文面 2件中 1-2件を表示")
    expect(page_text).to include("1ページあたり25件まで表示します。per_page は最大100件です。")
    expect(link_query("前へ")).to be_nil
    expect(link_query("次へ")).to be_nil
  end

  it "keeps the filtered empty state" do
    sign_in_as(admin_user)
    create_consent_term(1, title_prefix: "Existing Terms")

    get admin_consent_terms_path, params: { q: "missing" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する同意文面はありません。")
    expect(page_text).to include("条件をリセット")
    expect(page_text).not_to include("同意文面一覧の表示設定")
  end

  it "keeps the initial empty state" do
    sign_in_as(admin_user)

    get admin_consent_terms_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ同意文面はありません。")
    expect(page_text).not_to include("条件に一致する同意文面はありません。")
  end
end
