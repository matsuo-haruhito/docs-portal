require "rails_helper"

RSpec.describe "Admin document set query limit", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, code: "DOCSET", name: "Document Set Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def search_field
    parsed_html.at_css('form.document-set-filter-form input[name="q"]')
  end

  def listed_document_set_names
    parsed_html.css('tbody td[data-rails-table-preferences-column-key="name"]').map do |node|
      node.text.squish
    end
  end

  it "normalizes oversized search queries before filtering and rendering" do
    normalized_query = "A" * Admin::DocumentSetsController::DOCUMENT_SET_QUERY_MAX_LENGTH
    oversized_suffix = "B" * 40

    create(
      :document_set,
      project:,
      name: normalized_query,
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
    create(
      :document_set,
      project:,
      name: "Other document set",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 2
    )

    sign_in_as(admin)

    get admin_document_sets_path, params: {
      q: "  #{normalized_query}#{oversized_suffix}  ",
      set_type: "delivery",
      visibility_policy: "restricted_external"
    }

    expect(response).to have_http_status(:ok)
    expect(search_field["value"]).to eq(normalized_query)
    expect(search_field["maxlength"]).to eq(Admin::DocumentSetsController::DOCUMENT_SET_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("検索: #{normalized_query}")
    expect(page_text).not_to include(oversized_suffix)
    expect(page_text).to include("検索結果: 1件")
    expect(page_text).to include("種別: 送付用")
    expect(page_text).to include("公開範囲: 限定公開")
    expect(listed_document_set_names).to eq([normalized_query])
  end

  it "keeps empty filtered results bounded by the normalized query" do
    normalized_query = "Z" * Admin::DocumentSetsController::DOCUMENT_SET_QUERY_MAX_LENGTH
    oversized_suffix = "Q" * 40

    create(:document_set, project:, name: "Searchable set", sort_order: 1)

    sign_in_as(admin)

    get admin_document_sets_path, params: { q: "#{normalized_query}#{oversized_suffix}" }

    expect(response).to have_http_status(:ok)
    expect(search_field["value"]).to eq(normalized_query)
    expect(page_text).to include("検索: #{normalized_query}")
    expect(page_text).not_to include(oversized_suffix)
    expect(page_text).to include("検索結果: 0件")
    expect(page_text).to include("条件に一致する文書セットはありません。")
    expect(parsed_html.css('a[href]').select { |node| node.text.squish == "条件をクリア" }.map { |node| node["href"] }).to include(admin_document_sets_path)
  end

  it "treats LIKE wildcard characters as literal search text" do
    create(:document_set, project:, name: "100%確認セット", sort_order: 1)
    create(:document_set, project:, name: "通常確認セット", sort_order: 2)

    sign_in_as(admin)

    get admin_document_sets_path, params: { q: "%" }

    expect(response).to have_http_status(:ok)
    expect(search_field["value"]).to eq("%")
    expect(listed_document_set_names).to eq(["100%確認セット"])
    expect(page_text).to include("検索: %")
  end
end
