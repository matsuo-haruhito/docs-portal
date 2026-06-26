require "rails_helper"

RSpec.describe "Admin external folder sync sources empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "links the first-time empty state to Microsoft Graph connection management" do
    sign_in_as(admin_user)

    get admin_external_folder_sync_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まだ外部フォルダ同期設定は登録されていません。")
    expect(response.body).to include("上の「外部フォルダ同期設定を追加」で対象案件")
    expect(response.body).to include("SharePoint / OneDrive を使うときは、先に")
    expect(response.body).to include("Google Drive の dry-run / apply とは別の事前確認入口です。")

    graph_link = parsed_html.css("a").find { |node| node.text.strip == "Microsoft Graph接続を確認する" }
    expect(graph_link).to be_present
    expect(graph_link["href"]).to eq(admin_microsoft_graph_connections_path)
  end

  it "does not show the first-time Graph connection cue for search-result empty states" do
    sign_in_as(admin_user)
    create(:external_folder_sync_source, name: "Finance policies")

    get admin_external_folder_sync_sources_path, params: { q: "missing-source" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在の検索 / 絞り込みに一致する外部フォルダ同期設定はありません。")
    expect(response.body).not_to include("まだ外部フォルダ同期設定は登録されていません。")
    expect(response.body).not_to include("Microsoft Graph接続を確認する")
    expect(response.body).not_to include("Google Drive の dry-run / apply とは別の事前確認入口です。")
  end
end
