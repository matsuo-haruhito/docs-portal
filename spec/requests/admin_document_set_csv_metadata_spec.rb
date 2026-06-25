require "rails_helper"

RSpec.describe "Admin document set CSV metadata", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, code: "META", name: "Metadata Project") }

  def json_body
    JSON.parse(response.body)
  end

  it "returns companion metadata for the current CSV filters without row data" do
    matching_set = create(
      :document_set,
      project:,
      name: "Metadata delivery set",
      set_type: :delivery,
      visibility_policy: :restricted_external
    )
    create(
      :document_set,
      project:,
      name: "Metadata internal set",
      set_type: :delivery,
      visibility_policy: :internal_only
    )
    create(
      :document_set,
      project:,
      name: "Design public set",
      set_type: :design,
      visibility_policy: :public_with_login
    )

    sign_in_as(admin)
    get admin_document_sets_path(format: :json), params: {
      q: "  Metadata delivery  ",
      set_type: "delivery",
      visibility_policy: "restricted_external"
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")

    metadata = json_body
    expect(metadata).to include(
      "report_type" => "document_sets",
      "export_scope" => "current_filters",
      "row_count" => 1,
      "csv_headers" => Admin::DocumentSetsController::CSV_HEADERS,
      "ignored_filters" => {}
    )
    expect(metadata.fetch("description")).to include("CSV本体の行データではありません")
    expect(metadata.fetch("filters")).to include(
      "q" => { "value" => "Metadata delivery" },
      "set_type" => { "value" => "delivery", "label" => "送付用" },
      "visibility_policy" => { "value" => "restricted_external", "label" => "限定公開" }
    )
    expect(metadata.fetch("summary")).to include(
      "matching_document_sets" => 1,
      "filter_labels" => contain_exactly("検索: Metadata delivery", "種別: 送付用", "公開範囲: 限定公開"),
      "csv_filename" => "document-sets-#{Date.current.iso8601}.csv",
      "csv_columns_fixed" => true
    )
    expect(metadata).not_to have_key("document_sets")
    expect(metadata).not_to have_key("rows")
    expect(metadata.to_json).not_to include(matching_set.public_id)
  end

  it "ignores unsupported enum filters like the CSV scope and reports them separately" do
    create(:document_set, project:, name: "Delivery set", set_type: :delivery, visibility_policy: :restricted_external)
    create(:document_set, project:, name: "Design set", set_type: :design, visibility_policy: :public_with_login)

    sign_in_as(admin)
    get admin_document_sets_path(format: :json), params: {
      set_type: "unsupported_type",
      visibility_policy: "private_scope"
    }

    expect(response).to have_http_status(:ok)

    metadata = json_body
    expect(metadata.fetch("row_count")).to eq(2)
    expect(metadata.fetch("filters")).to eq({})
    expect(metadata.fetch("ignored_filters")).to eq(
      "set_type" => "unsupported_type",
      "visibility_policy" => "private_scope"
    )
    expect(metadata.fetch("csv_headers")).to eq(Admin::DocumentSetsController::CSV_HEADERS)
  end
end
