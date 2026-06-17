require "rails_helper"
require "uri"

RSpec.describe "Admin document set export actions", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def csv_export_link
    parsed_html.css("form.document-set-filter-form a[href]").find { |node| node.text.squish == "CSV出力" }
  end

  def csv_export_query
    Rack::Utils.parse_nested_query(URI.parse(csv_export_link["href"]).query)
  end

  it "explains CSV scope while keeping current filter params" do
    create(
      :document_set,
      project:,
      name: "配送社内セット",
      set_type: :delivery,
      visibility_policy: :internal_only,
      sort_order: 1
    )
    create(
      :document_set,
      project:,
      name: "設計公開セット",
      set_type: :design,
      visibility_policy: :public_with_login,
      sort_order: 2
    )

    sign_in_as(admin)

    get admin_document_sets_path, params: {
      q: "配送",
      set_type: "delivery",
      visibility_policy: "internal_only"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("CSV出力は現在の絞り込み条件に一致する文書セット集合を、表示設定の列表示・幅とは独立した固定列で出力します。")
    expect(page_text).to include("種別: 送付用")
    expect(page_text).to include("公開範囲: 社内のみ")
    expect(page_text).to include("検索結果: 1件")

    expect(URI.parse(csv_export_link["href"]).path).to end_with(".csv")
    expect(csv_export_query).to include(
      "q" => "配送",
      "set_type" => "delivery",
      "visibility_policy" => "internal_only"
    )
  end
end
