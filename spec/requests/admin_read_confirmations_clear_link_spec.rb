require "rails_helper"

RSpec.describe "Admin read confirmations clear link", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def filter_action_links
    parsed_html.css("section.card").first.css("p.actions a").map { _1.text.squish }
  end

  it "hides the top clear link when there are no removable conditions" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path

    expect(response).to have_http_status(:ok)
    expect(filter_action_links).not_to include("条件をクリア")
    expect(parsed_html.text.squish).to include("案件を選択すると既読確認の内訳を表示します。")
  end

  it "shows the top clear link when a project is selected" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(filter_action_links).to include("条件をクリア")
  end

  it "shows the top clear link when document or invalid date filters are present" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path(document_slug: "manual")

    expect(response).to have_http_status(:ok)
    expect(filter_action_links).to include("条件をクリア")

    get admin_read_confirmations_path(from: "not-a-date")

    expect(response).to have_http_status(:ok)
    expect(filter_action_links).to include("条件をクリア")
  end

  it "keeps the project-only recovery link in the empty result state" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css("a").map { _1.text.squish }).to include("案件だけ残して条件を解除")
  end
end
