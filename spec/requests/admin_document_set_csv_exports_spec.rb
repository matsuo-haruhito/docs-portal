require "csv"
require "rails_helper"

RSpec.describe "Admin document set CSV exports", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }
  let(:document_a) { create(:document, project:, title: "概要仕様", slug: "overview") }
  let(:document_b) { create(:document, project:, title: "社内メモ", slug: "internal-memo") }

  let!(:existing_document_set) do
    create(
      :document_set,
      project:,
      name: "既存セット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end

  let!(:delivery_internal_set) do
    create(
      :document_set,
      project:,
      name: "配送社内セット",
      set_type: :delivery,
      visibility_policy: :internal_only,
      sort_order: 2
    )
  end

  let!(:design_public_set) do
    create(
      :document_set,
      project:,
      name: "設計公開セット",
      set_type: :design,
      visibility_policy: :public_with_login,
      sort_order: 3
    )
  end

  def parsed_csv
    CSV.parse(response.body, headers: true)
  end

  def csv_headers
    parsed_csv.headers
  end

  def csv_rows
    parsed_csv.map(&:to_h)
  end

  def csv_names
    csv_rows.map { |row| row.fetch("文書セット名") }
  end

  def csv_row_for(document_set)
    csv_rows.find { |row| row.fetch("public_id") == document_set.public_id }
  end

  def create_table_preference!
    RailsTablePreferences::Preference.create!(
      user: admin,
      table_key: "admin_document_sets",
      name: "default",
      settings: {
        "columns" => [
          { "key" => "project", "visible" => false, "width" => 260, "order" => 1 },
          { "key" => "name", "visible" => true, "width" => 300, "order" => 2 },
          { "key" => "documents_count", "visible" => false, "width" => 120, "order" => 3 }
        ],
        "filters" => {
          "set_type" => { "operator" => "eq", "value" => "design" },
          "visibility_policy" => { "operator" => "eq", "value" => "public_with_login" }
        }
      }
    )
  end

  it "exports only the current filtered document sets with the stable CSV contract" do
    create(:document_set_item, document_set: existing_document_set, document: document_a, sort_order: 1)
    create(:document_set_item, document_set: delivery_internal_set, document: document_b, sort_order: 1)

    sign_in_as(admin)

    get admin_document_sets_path(format: :csv), params: {
      q: "配送",
      set_type: "delivery",
      visibility_policy: "internal_only"
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_headers).to eq(Admin::DocumentSetsController::CSV_HEADERS)
    expect(csv_names).to eq(["配送社内セット"])

    row = csv_row_for(delivery_internal_set)
    expect(row).to include(
      "案件コード" => project.code,
      "案件名" => "Delivery Project",
      "文書セット名" => "配送社内セット",
      "種別" => "送付用",
      "公開範囲" => "社内のみ",
      "文書数" => "1",
      "public_id" => delivery_internal_set.public_id
    )
  end

  it "keeps unsupported filters and saved table preferences from changing CSV rows or headers" do
    create_table_preference!

    sign_in_as(admin)

    get admin_document_sets_path(format: :csv), params: {
      set_type: "unsupported_type",
      visibility_policy: "unsupported_visibility"
    }

    expect(response).to have_http_status(:ok)
    expect(csv_headers).to eq(Admin::DocumentSetsController::CSV_HEADERS)
    expect(csv_names).to eq(["既存セット", "配送社内セット", "設計公開セット"])
    expect(csv_rows.map(&:keys)).to all(eq(Admin::DocumentSetsController::CSV_HEADERS))
  end
end
