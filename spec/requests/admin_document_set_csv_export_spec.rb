require "rails_helper"
require "csv"
require "uri"

RSpec.describe "Admin document set CSV export", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, code: "DELIV", name: "Delivery Project") }
  let(:document_a) { create(:document, project:, title: "概要仕様", slug: "overview") }
  let(:document_b) { create(:document, project:, title: "社内メモ", slug: "internal-memo") }
  let!(:target_set) do
    create(
      :document_set,
      project:,
      name: "既存セット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end
  let!(:internal_set) do
    create(
      :document_set,
      project:,
      name: "配送社内セット",
      set_type: :delivery,
      visibility_policy: :internal_only,
      sort_order: 2
    )
  end
  let!(:design_set) do
    create(
      :document_set,
      project:,
      name: "設計公開セット",
      set_type: :design,
      visibility_policy: :public_with_login,
      sort_order: 3
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def csv_export_href
    parsed_html.css("a[href]").find { |node| node.text.squish == "CSV出力" }["href"]
  end

  def csv_export_query
    Rack::Utils.parse_nested_query(URI.parse(csv_export_href).query)
  end

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  before do
    create(:document_set_item, document_set: target_set, document: document_a, sort_order: 1)
    create(:document_set_item, document_set: target_set, document: document_b, sort_order: 2)
    create(:document_set_item, document_set: internal_set, document: document_a, sort_order: 1)
  end

  it "links to the CSV export with the current list filters" do
    sign_in_as(admin)

    get admin_document_sets_path, params: {
      q: "既存",
      set_type: "delivery",
      visibility_policy: "restricted_external"
    }

    expect(response).to have_http_status(:ok)
    expect(URI.parse(csv_export_href).path).to eq("/admin/document_sets.csv")
    expect(csv_export_query).to include(
      "q" => "既存",
      "set_type" => "delivery",
      "visibility_policy" => "restricted_external"
    )
  end

  it "exports only document sets matching the current filters with stable operator-readable columns" do
    sign_in_as(admin)

    get admin_document_sets_path(format: :csv), params: {
      q: "既存",
      set_type: "delivery",
      visibility_policy: "restricted_external"
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("document-sets-")

    rows = csv_rows
    expect(rows.headers).to eq([
      "案件コード",
      "案件名",
      "文書セット名",
      "種別",
      "公開範囲",
      "文書数",
      "public_id"
    ])
    expect(rows.map { |row| row["文書セット名"] }).to eq(["既存セット"])
    expect(rows.first.to_h).to include(
      "案件コード" => project.code,
      "案件名" => "Delivery Project",
      "文書セット名" => "既存セット",
      "種別" => "送付用",
      "公開範囲" => "限定公開",
      "文書数" => "2",
      "public_id" => target_set.public_id
    )
    expect(response.body).not_to include("配送社内セット")
    expect(response.body).not_to include("設計公開セット")
    expect(rows.headers).not_to include("操作")
  end
end
