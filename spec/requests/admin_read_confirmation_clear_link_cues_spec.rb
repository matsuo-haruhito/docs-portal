require "rails_helper"

RSpec.describe "Admin read confirmation clear link cues", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "READ", name: "Read Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def clear_link
    parsed_html.css("a").find { _1.text.squish == "条件をクリア" }
  end

  it "does not show the clear link when only the page query is present" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択してください")
    expect(clear_link).to be_nil
  end

  it "keeps the clear link when a real filter condition is present" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Read Project")
    expect(clear_link).to be_present
    expect(clear_link["href"]).to eq(admin_read_confirmations_path)
  end
end
