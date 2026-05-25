require "rails_helper"

RSpec.describe "Admin Microsoft Graph connections", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  describe "GET /admin/microsoft_graph_connections" do
    it "shows which enabled connection is currently used for preview" do
      sign_in_as(admin_user)
      active = create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      create(:microsoft_graph_connection, project:, name: "Standby connection", enabled: false)
      create(:microsoft_graph_connection, project: create(:project, code: "GRAPH002", name: "Other Project"), name: "Other active", enabled: true)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active.name)
      expect(response.body).to include("previewで使用中")
      expect(response.body).to include("previewでは未使用")
    end

    it "highlights legacy duplicate enabled connections that need cleanup" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, name: "Primary connection", enabled: true)
      duplicate = build(:microsoft_graph_connection, project:, name: "Duplicate connection", enabled: true)
      duplicate.save!(validate: false)

      get admin_microsoft_graph_connections_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("同一案件に複数の有効接続が残っています")
      expect(response.body).to include("有効だが未使用")
      expect(response.body).to include("別の有効接続が preview に使われます")
    end
  end

  describe "POST /admin/microsoft_graph_connections" do
    it "rejects creating a second enabled connection for the same project" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, enabled: true)

      expect do
        post admin_microsoft_graph_connections_path, params: {
          microsoft_graph_connection: {
            project_id: project.id,
            name: "Replacement connection",
            auth_type: "client_credentials",
            tenant_id: "tenant-id",
            client_id: "client-id",
            client_secret: "client-secret",
            site_id: "site-id",
            drive_id: "drive-id-2",
            preview_folder_path: "docs-portal-previews-2",
            enabled: "true"
          }
        }
      end.not_to change(MicrosoftGraphConnection, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("同一案件で1件だけ有効にできます")
      expect(response.body).to include("現在の有効接続を先に無効化")
    end
  end
end