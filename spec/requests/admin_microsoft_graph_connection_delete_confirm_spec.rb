require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection delete confirmations", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  it "adds project, connection, and preview usage context without exposing raw Graph identifiers" do
    sign_in_as(admin_user)
    long_tenant_id = "tenant-#{'northwind-' * 8}primary"
    long_client_id = "client-#{'application-' * 8}id"
    long_drive_id = "b!#{'driveIdentifierSegment' * 5}"
    active = create(
      :microsoft_graph_connection,
      project:,
      name: "Primary connection",
      tenant_id: long_tenant_id,
      client_id: long_client_id,
      drive_id: long_drive_id,
      enabled: true
    )
    standby = create(:microsoft_graph_connection, project:, name: "Standby connection", enabled: false)
    standby.update_column(:enabled, true)
    disabled = create(:microsoft_graph_connection, project:, name: "Disabled connection", enabled: false)

    get admin_microsoft_graph_connections_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_microsoft_graph_connection_path(active))
    expect(response.body).to include("案件: GRAPH001 / Graph Project、接続名: Primary connection、preview利用: previewで使用中")
    expect(response.body).to include("Tenant / Client / Drive ID は一覧または編集画面で確認してください。")
    expect(response.body).not_to include(long_tenant_id)
    expect(response.body).not_to include(long_client_id)
    expect(response.body).not_to include(long_drive_id)

    expect(response.body).to include(admin_microsoft_graph_connection_path(standby))
    expect(response.body).to include("接続名: Standby connection、preview利用: 有効だが未使用")

    expect(response.body).to include(admin_microsoft_graph_connection_path(disabled))
    expect(response.body).to include("接続名: Disabled connection、preview利用: previewでは未使用")
  end
end
