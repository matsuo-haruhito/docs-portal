require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection search cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  describe "GET /admin/microsoft_graph_connections" do
    it "shows the search target cue and matches maxlength to the server-side query boundary" do
      sign_in_as(admin_user)
      project = create(:project, code: "GRAPH001", name: "Graph Project")
      create(:microsoft_graph_connection, project:, name: "Primary connection")

      get admin_microsoft_graph_connections_path

      search_input = parsed_html.at_css(%(input[name="q"]))

      expect(response).to have_http_status(:ok)
      expect(search_input).to be_present
      expect(search_input["maxlength"]).to eq(Admin::MicrosoftGraphConnectionsController::MAX_SEARCH_QUERY_LENGTH.to_s)
      expect(response.body).to include("検索対象: 案件名・code・接続名・Tenant / Client / Drive / Site ID・プレビュー用フォルダ")
      expect(response.body).to include("最大#{Admin::MicrosoftGraphConnectionsController::MAX_SEARCH_QUERY_LENGTH}文字")
    end
  end
end
