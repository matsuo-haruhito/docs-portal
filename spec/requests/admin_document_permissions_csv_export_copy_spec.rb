require "rails_helper"

RSpec.describe "Admin document permissions CSV export copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_texts
    parsed_html.css("a[href]").map { _1.text.squish }
  end

  def csv_export_link
    parsed_html.css("a[href]").find { _1.text.squish == "CSV出力" }
  end

  it "explains that CSV export follows current filters without depending on table columns" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("CSVは現在の検索条件で出力します。文書別の権限概要・権限一覧の列表示設定とは独立した固定項目です。")
    expect(csv_export_link["href"]).to eq(admin_document_permissions_path(format: :csv))
    expect(link_texts).not_to include("条件をクリア")
  end

  it "keeps active filters in the CSV export link next to the copy" do
    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "manual", access_level: "view")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("CSVは現在の検索条件で出力します。文書別の権限概要・権限一覧の列表示設定とは独立した固定項目です。")
    expect(page_text).to include("有効な条件:")
    expect(csv_export_link["href"]).to eq(admin_document_permissions_path(q: "manual", access_level: "view", format: :csv))
    expect(link_texts).to include("条件をクリア")
  end
end
