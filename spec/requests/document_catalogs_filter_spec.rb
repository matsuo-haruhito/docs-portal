require "rails_helper"

RSpec.describe "Document catalog filters", type: :request do
  let(:project) { create(:project, name: "Catalog Project") }
  let(:user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def catalog_table_text
    parsed_html.at_css("table tbody")&.text.to_s.squish
  end

  it "keeps name and description as the only catalog query targets" do
    create(:document_catalog, project:, name: "Needle Catalog", description: "General catalog")
    create(:document_catalog, project:, name: "Description Catalog", description: "Needle appears in this description")
    item_only_catalog = create(:document_catalog, project:, name: "Catalog item only", description: "No direct match")
    item_document = create(:document, project:, title: "Needle item document", slug: "needle-item-document")
    create(:document_catalog_item, document_catalog: item_only_catalog, document: item_document)

    sign_in_as(user)

    get project_document_catalogs_path(project), params: { q: "  needle  " }

    expect(response).to have_http_status(:ok)
    expect(catalog_table_text).to include("Needle Catalog")
    expect(catalog_table_text).to include("Description Catalog")
    expect(catalog_table_text).not_to include("Catalog item only")
    expect(catalog_table_text).not_to include("Needle item document")

    search_input = parsed_html.at_css('input[name="q"]')
    expect(search_input["value"]).to eq("needle")
    expect(search_input["maxlength"]).to eq("100")
    expect(parsed_html.text.squish).to include("名称・説明: needle")
    expect(parsed_html.text.squish).to include("カタログ名・説明が対象です。文書本文・item文書名・添付ファイル名は対象外です。100文字まで入力できます。")
  end

  it "bounds overlong queries before rendering filter labels and reusable URLs" do
    bounded_query = "a" * DocumentCatalogsController::CATALOG_QUERY_MAX_LENGTH
    overlong_query = " #{bounded_query}z "
    create(:document_catalog, project:, name: bounded_query, description: "Bounded query catalog")

    sign_in_as(user)

    get project_document_catalogs_path(project), params: { q: overlong_query }

    expect(response).to have_http_status(:ok)
    expect(catalog_table_text).to include(bounded_query)

    search_input = parsed_html.at_css('input[name="q"]')
    expect(search_input["value"]).to eq(bounded_query)
    expect(search_input["value"].length).to eq(DocumentCatalogsController::CATALOG_QUERY_MAX_LENGTH)
    expect(parsed_html.text.squish).to include("名称・説明: #{bounded_query}")
    expect(parsed_html.text.squish).not_to include(overlong_query.strip)

    reusable_url = parsed_html.at_css('a', text: "現在の条件のURLを開く")["href"]
    expect(CGI.unescape(reusable_url)).to include("q=#{bounded_query}")
    expect(CGI.unescape(reusable_url)).not_to include("q=#{overlong_query.strip}")
  end

  it "keeps the filtered empty state and reset link when no catalogs match" do
    create(:document_catalog, project:, name: "Operations Catalog", description: "Runbook collection")

    sign_in_as(user)

    get project_document_catalogs_path(project), params: { q: "missing" }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("条件に一致する文書カタログはありません")
    expect(parsed_html.text.squish).to include("名称・説明: missing")

    reset_link = parsed_html.at_css(".document-catalog-empty-state a")
    expect(reset_link.text.squish).to eq("絞り込み解除")
    expect(reset_link["href"]).to eq(project_document_catalogs_path(project))
  end
end
