require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection safe previews", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows safe previews for long Graph identifiers without exposing raw values" do
    sign_in_as(admin_user)
    long_tenant_id = "tenant-#{'northwind-' * 8}primary"
    long_client_id = "client-#{'application-' * 8}id"
    long_drive_id = "b!#{'driveIdentifierSegment' * 5}"
    long_site_id = "contoso.sharepoint.com,#{'site-id-' * 6}web-id"
    long_folder_path = "Shared Documents/#{'Department Folder/' * 5}Office Preview"
    connection = create(
      :microsoft_graph_connection,
      project:,
      name: "Long identifiers",
      tenant_id: long_tenant_id,
      client_id: long_client_id,
      site_id: long_site_id,
      drive_id: long_drive_id,
      preview_folder_path: long_folder_path,
      enabled: true
    )

    get admin_microsoft_graph_connections_path

    row = parsed_html.css("tbody tr").find { |node| node.text.include?(connection.name) }
    preview_values = row.css("code.graph-connection-value").map { |node| node.text.squish }

    expect(response).to have_http_status(:ok)
    expect(row).to be_present
    expect(response.body).to include("一覧の識別子は短縮表示です。raw 値の照合や修正が必要な場合は、対象行の「編集」で確認してください。")
    expect(preview_values).to include(safe_identifier_preview(long_drive_id))
    expect(preview_values).to include(safe_identifier_preview(long_folder_path))
    expect(preview_values).to include(safe_identifier_preview(long_tenant_id))
    expect(preview_values).to include(safe_identifier_preview(long_client_id))
    expect(preview_values).to include(safe_identifier_preview(long_site_id))
    expect(preview_values).to all(include("..."))
    expect(response.body).not_to include(long_drive_id)
    expect(response.body).not_to include(long_folder_path)
    expect(response.body).not_to include(long_tenant_id)
    expect(response.body).not_to include(long_client_id)
    expect(response.body).not_to include(long_site_id)
    expect(row.text.squish).to include("主確認: Drive ID")
    expect(row.text.squish).to include("主確認: プレビュー用フォルダ")
    expect(row.text.squish).to include("補助: Tenant ID")
    expect(row.text.squish).to include("補助: Client ID")
    expect(row.text.squish).to include("補助: Site ID")
    expect(row.at_css(%(a[href="#{edit_admin_microsoft_graph_connection_path(connection)}"])).text).to include("編集")
  end

  it "masks secret-like fragments and private-looking paths in the list preview" do
    sign_in_as(admin_user)
    connection = create(:microsoft_graph_connection, project:, name: "Sensitive identifiers", enabled: true)
    connection.update_columns(
      tenant_id: "Authorization: Bearer graph-token-123",
      client_id: "client_secret=raw-client-secret",
      site_id: "access_token=raw-access-token",
      drive_id: "token=raw-drive-token",
      preview_folder_path: "/Users/alice/Secret Preview Folder"
    )

    get admin_microsoft_graph_connections_path

    row = parsed_html.css("tbody tr").find { |node| node.text.include?("Sensitive identifiers") }
    preview_values = row.css("code.graph-connection-value").map { |node| node.text.squish }

    expect(response).to have_http_status(:ok)
    expect(preview_values.join(" ")).to include("Authorization: [masked]")
    expect(preview_values.join(" ")).to include("client_secret=[masked]")
    expect(preview_values.join(" ")).to include("access_token=[masked]")
    expect(preview_values.join(" ")).to include("token=[masked]")
    expect(preview_values.join(" ")).to include("[path hidden]")
    expect(response.body).not_to include("graph-token-123")
    expect(response.body).not_to include("raw-client-secret")
    expect(response.body).not_to include("raw-access-token")
    expect(response.body).not_to include("raw-drive-token")
    expect(response.body).not_to include("/Users/alice/Secret Preview Folder")
  end

  def safe_identifier_preview(value)
    normalized = value.to_s.squish
    return normalized if normalized.length <= 28

    "#{normalized.first(10)}...#{normalized.last(8)}"
  end
end
