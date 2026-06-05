require "rails_helper"

RSpec.describe "Admin Microsoft Graph external sync navigation", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GRAPH001", name: "Graph Project") }

  it "links each Graph connection to the same project SharePoint / OneDrive sync settings" do
    sign_in_as(admin_user)
    connection = create(:microsoft_graph_connection, project:, name: "Office preview", enabled: true)

    get admin_microsoft_graph_connections_path

    row = parsed_html.css("tbody tr").find { |node| node.text.include?(connection.name) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("SharePoint / OneDrive の外部フォルダ同期は metadata 確認のみです。")
    expect(response.body).to include("dry-run / apply は外部フォルダ同期設定側でも未対応です。")
    expect(row).to be_present
    expect(row.text.squish).to include("外部フォルダ同期設定を確認")
    expect(row.text.squish).to include("SharePoint / OneDrive metadata 設定へ移動")
    expect(row.at_css(%(a[href="#{admin_external_folder_sync_sources_path(review: :microsoft_graph, q: project.code)}"]))).to be_present
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end
end
