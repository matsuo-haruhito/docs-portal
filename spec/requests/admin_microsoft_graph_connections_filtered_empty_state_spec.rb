require "rails_helper"

RSpec.describe "Admin Microsoft Graph connections filtered empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_href(text)
    parsed_html.css("a").find { |link| link.text.squish == text }&.[]("href")
  end

  describe "GET /admin/microsoft_graph_connections" do
    it "shows the active search and preview filter context when filtered results are empty" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)

      get admin_microsoft_graph_connections_path, params: { preview_usage: "preview_selected", q: "missing" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("現在の絞り込みに一致する Microsoft Graph接続はありません。")
      expect(response.body).to include("現在の絞り込み: previewで使用中 / 検索: missing")
      expect(response.body).to include("previewで使用中の接続がないか、検索語で除外されています。")
      expect(response.body).to include("検索語「missing」で登録済み接続を絞り込んでいます。")
      expect(link_href("検索だけ解除")).to eq(admin_microsoft_graph_connections_path(preview_usage: "preview_selected"))
      expect(link_href("preview利用状態をすべてに戻す")).to eq(admin_microsoft_graph_connections_path(q: "missing"))
      expect(link_href("検索と絞り込みを解除")).to eq(admin_microsoft_graph_connections_path)
      expect(response.body).not_to include("まだMicrosoft Graph接続は登録されていません。")
    end

    it "shows duplicate filter context separately from all reset when duplicate results are empty" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)

      get admin_microsoft_graph_connections_path, params: { duplicate_only: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("現在の絞り込み: 要整理案件のみ")
      expect(response.body).to include("同一案件に複数の有効接続が残る案件がないか")
      expect(link_href("要整理案件のみを解除")).to eq(admin_microsoft_graph_connections_path)
      expect(link_href("検索と絞り込みを解除")).to eq(admin_microsoft_graph_connections_path)
      expect(response.body).not_to include("まだMicrosoft Graph接続は登録されていません。")
    end
  end
end
