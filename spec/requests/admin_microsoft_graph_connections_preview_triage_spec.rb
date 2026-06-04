require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection preview triage", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  describe "GET /admin/microsoft_graph_connections" do
    it "shows the Office preview failure triage path near the connection list" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Office preview が開かないときの確認順")
      expect(response.body).to include("対象案件の「previewで使用中」行を最初に確認")
      expect(response.body).to include("Drive ID、プレビュー用フォルダ、Tenant / Client の順")
      expect(response.body).to include("preview 不達時はこの行の Drive ID / プレビュー用フォルダ / Tenant / Client を最初に確認してください")
      expect(parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(preview_usage: :preview_selected)}"]))).to be_present
      expect(parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(duplicate_only: 1)}"]))).to be_present
    end

    it "explains duplicate enabled connections without changing preview selection policy" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = create(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: false)
      duplicate.update_column(:enabled, true)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("current preview が最小 DB id の接続に寄る可能性")
      expect(response.body).to include("どの接続を残すかは案件担当者の確認後に判断")
      expect(response.body).to include("「previewで使用中」は暫定的に最小 DB id の行を指すことがあります")
      expect(response.body).to include("重複整理では残す接続を人間が確認してください")
    end

    it "keeps the current search query on preview triage links" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Archive primary", enabled: true)

      get admin_microsoft_graph_connections_path, params: { q: "Archive" }

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(preview_usage: :preview_selected, q: "Archive")}"]))).to be_present
      expect(parsed_html.at_css(%(a[href="#{admin_microsoft_graph_connections_path(duplicate_only: 1, q: "Archive")}"]))).to be_present
    end
  end
end
