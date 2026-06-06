require "rails_helper"

RSpec.describe "Admin model browser index layout", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def group_sections
    parsed_html.css("section.model-browser-group")
  end

  it "shows group summaries before cards while keeping card metrics aligned" do
    create(:project)
    create(:document)

    sign_in_as(admin_user)
    get admin_model_browser_path

    expect(response).to have_http_status(:ok)

    basic_master = group_sections.find { _1.at_css("h2")&.text&.squish == "基本マスタ" }
    document_permission = group_sections.find { _1.at_css("h2")&.text&.squish == "文書・権限" }

    expect(basic_master).to be_present
    expect(document_permission).to be_present
    expect(basic_master.at_css(".model-browser-group-summary").text.squish).to match(/\A\d+モデル \/ 合計[\d,]+件 \/ 最終更新 /)
    expect(document_permission.at_css(".model-browser-group-summary").text.squish).to match(/\A\d+モデル \/ 合計[\d,]+件 \/ 最終更新 /)

    project_card = group_sections.css(".metric-card").find { _1.at_css("h3 a")&.text&.squish == "案件" }

    expect(project_card).to be_present
    expect(project_card.at_css(".model-browser-card-description").text.squish).to include("公開単位")
    expect(project_card.at_css(".model-browser-card-metrics").text.squish).to include("件数")
    expect(project_card.at_css(".model-browser-card-metrics").text.squish).to include("最終更新")
    expect(project_card.at_css("a.button")["href"]).to eq(admin_model_browser_model_path("projects"))
  end

  it "keeps filtered groups summarized without changing search behavior" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "外部連携" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件: 外部連携")
    expect(group_sections.map { _1.at_css("h2").text.squish }).to eq(["外部連携"])
    expect(group_sections.first.at_css(".model-browser-group-summary").text.squish).to match(/\A\d+モデル \/ 合計[\d,]+件 \/ 最終更新 /)
    expect(group_sections.first.css(".metric-card h3 a").map { _1.text.squish }).to include("Webhook")
  end
end
