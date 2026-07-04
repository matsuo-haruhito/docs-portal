require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection empty state actions", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def filtered_empty_state_card
    parsed_html.xpath("//div[contains(concat(' ', normalize-space(@class), ' '), ' card ')][.//p[contains(normalize-space(.), '現在の絞り込みに一致する Microsoft Graph接続はありません。')]]").first
  end

  it "shows a button-style reset action in the filtered empty state" do
    sign_in_as(admin_user)
    create(:microsoft_graph_connection, project:, name: "Primary connection")

    get admin_microsoft_graph_connections_path, params: { q: "missing" }

    expect(response).to have_http_status(:ok)
    expect(filtered_empty_state_card).to be_present

    reset_link = filtered_empty_state_card.css(".actions a.button.secondary").find { |link| link.text.squish == "検索と絞り込みを解除" }
    expect(reset_link).to be_present
    expect(reset_link["href"]).to eq(admin_microsoft_graph_connections_path)
  end

  it "keeps the unregistered empty state separate from the filtered reset action" do
    sign_in_as(admin_user)

    get admin_microsoft_graph_connections_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まだMicrosoft Graph接続は登録されていません。")
    expect(filtered_empty_state_card).to be_nil
    expect(parsed_html.at_css(".actions a.button.secondary")&.text.to_s).not_to include("検索と絞り込みを解除")
  end
end
