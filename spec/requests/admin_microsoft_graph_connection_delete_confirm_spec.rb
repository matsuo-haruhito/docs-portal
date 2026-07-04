require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection delete confirmations", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def row_for(connection)
    parsed_html.css("tbody tr").find { |row| row.text.include?(connection.name) }
  end

  def delete_confirm_for(connection)
    delete_link = row_for(connection).css(%(a[href="#{admin_microsoft_graph_connection_path(connection)}"])).find { |link| link.text.squish == "削除" }

    delete_link["data-turbo-confirm"] || delete_link["data-confirm"]
  end

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

    active_confirm = delete_confirm_for(active)
    standby_confirm = delete_confirm_for(standby)
    disabled_confirm = delete_confirm_for(disabled)

    expect(response).to have_http_status(:ok)
    expect(active_confirm).to include("案件: GRAPH001 / Graph Project")
    expect(active_confirm).to include("接続名: Primary connection")
    expect(active_confirm).to include("preview利用: previewで使用中")
    expect(active_confirm).to include("Tenant / Client / Drive ID は一覧または編集画面で確認してください。")
    expect(active_confirm).not_to include(long_tenant_id)
    expect(active_confirm).not_to include(long_client_id)
    expect(active_confirm).not_to include(long_drive_id)

    expect(standby_confirm).to include("接続名: Standby connection")
    expect(standby_confirm).to include("preview利用: 有効だが未使用")

    expect(disabled_confirm).to include("接続名: Disabled connection")
    expect(disabled_confirm).to include("preview利用: previewでは未使用")
  end
end
