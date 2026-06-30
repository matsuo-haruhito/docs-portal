require "rails_helper"

RSpec.describe "Admin model browser empty reset link", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def result_section_links
    parsed_html.css("section.card").last.css("a[href]")
  end

  it "shows a reset link near the empty record search state" do
    create(:project, code: "MISS1674", name: "Miss Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects"), params: { model_browser_q: "文書", q: "NO_MATCH_4284" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("該当する代表データはありません。")
    expect(response.body).to include("既存画面でも同じ検索語で確認できます。")

    empty_state_links = result_section_links.map { |link| [link.text.squish, link["href"]] }
    expect(empty_state_links).to include([
      "検索を解除して最近のデータを見る",
      admin_model_browser_model_path("projects", model_browser_q: "文書")
    ])
  end

  it "does not show the empty reset link when recent records are displayed" do
    create(:project, code: "RECENT4284", name: "Recent Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最近のデータ")
    expect(response.body).not_to include("検索を解除して最近のデータを見る")
  end
end
