require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection form copy", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def resolve_button
    parsed_html.at_css(%(button[name="resolve_share_url"]))
  end

  shared_examples "a form that separates save from shared URL resolving" do
    it "shows resolver copy as a non-saving form fill action" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("取得操作はフォームに候補を反映するだけです。接続設定の保存は別途「保存」が必要です。")
      expect(parsed_html.at_css(%(input[type="submit"][value="保存"]))).to be_present
      expect(resolve_button).to be_present
      expect(resolve_button.text.squish).to eq("共有URLから候補を取得（保存しない）")
      expect(resolve_button["value"]).to eq("1")
    end
  end

  describe "GET /admin/microsoft_graph_connections" do
    before do
      sign_in_as(admin_user)
      project
      get admin_microsoft_graph_connections_path
    end

    include_examples "a form that separates save from shared URL resolving"
  end

  describe "GET /admin/microsoft_graph_connections/:public_id/edit" do
    before do
      sign_in_as(admin_user)
      connection = create(:microsoft_graph_connection, project:, name: "Office preview")
      get edit_admin_microsoft_graph_connection_path(connection)
    end

    include_examples "a form that separates save from shared URL resolving"
  end
end
