require "rails_helper"

RSpec.describe "Admin document catalogs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "CAT", name: "Catalog Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let!(:document_a) { create(:document, project:, title: "導入ガイド", slug: "getting-started") }
  let!(:document_b) { create(:document, project:, title: "運用手順", slug: "operations") }
  let!(:other_document) { create(:document, project: other_project, title: "外部文書", slug: "outside") }
  let!(:version_a) { create(:document_version, document: document_a, version_label: "v1.0.0") }
  let!(:existing_catalog) do
    create(
      :document_catalog,
      project:,
      name: "既存カタログ",
      audience_type: :customer,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_response
    JSON.parse(response.body)
  end

  def form_select_names
    parsed_html.css('select[name^="document_catalog["]').map { |node| node["name"] }
  end

  def project_field
    parsed_html.at_css('[name="document_catalog[project_id]"]')
  end

  def catalog_item_row_for(document)
    parsed_html.at_css(%(tr[data-document-catalog-document-id="#{document.id}"]))
  end

  def listed_catalog_names
    parsed_html.css("table tbody tr td:nth-child(2) div").map { |node| node.text.squish }
  end

  it "renders the admin catalog form and navigation for admins only" do
    sign_in_as(admin)

    get admin_document_catalogs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書カタログ管理")
    expect(page_text).to include("文書カタログ")
    expect(form_select_names).to include(
      "document_catalog[project_id]",
      "document_catalog[audience_type]",
      "document_catalog[visibility_policy]"
    )
    expect(project_field["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_document_catalogs_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_document_catalogs_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentCatalogsController::PROJECT_SEARCH_LIMIT.to_s)
    expect(listed_catalog_names).to include("既存カタログ")

    sign_in_as(external_user)

    get admin_document_catalogs_path

    expect(response).to have_http_status(:forbidden)
  end

  it "searches and restores projects for the remote project picker" do
    sign_in_as(admin)

    get project_search_admin_document_catalogs_path(format: :json), params: { q: "cat" }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("options")).to contain_exactly(
      include("value" => project.id, "text" => "CAT / Catalog Project")
    )

    get selected_project_admin_document_catalogs_path(format: :json), params: { id: other_project.id }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to include(
      "value" => other_project.id,
      "text" => "OTHER / Other Project"
    )
  end

  it "searches documents inside the selected project only" do
    sign_in_as(admin)

    get document_search_admin_document_catalogs_path(format: :json), params: { project_id: project.id, q: "getting" }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("documents")).to contain_exactly(
      include(
        "id" => document_a.id,
        "title" => "導入ガイド",
        "slug" => "getting-started",
        "latest_version_label" => "v1.0.0"
      )
    )
    expect(json_response.fetch("options").map { _1.fetch("id") }).not_to include(other_document.id)
  end

  it "restores selected documents only when they belong to the selected project" do
    sign_in_as(admin)

    get selected_document_admin_document_catalogs_path(format: :json), params: { project_id: project.id, id: document_b.id }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to include(
      "id" => document_b.id,
      "title" => "運用手順",
      "slug" => "operations"
    )

    get selected_document_admin_document_catalogs_path(format: :json), params: { project_id: project.id, id: other_document.id }

    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to be_nil
  end

  it "keeps existing catalog items visible when they are outside the bounded candidate window" do
    extra_documents = create_list(:document, Admin::DocumentCatalogsController::DOCUMENT_SEARCH_LIMIT + 1, project:)
    selected_document = extra_documents.last
    create(:document_catalog_item, document_catalog: existing_catalog, document: selected_document, sort_order: 9, note: "selected outside first page")

    sign_in_as(admin)

    get edit_admin_document_catalog_path(existing_catalog)

    expect(response).to have_http_status(:ok)
    row = catalog_item_row_for(selected_document)
    expect(row).to be_present
    expect(row.at_css('input[type="checkbox"][checked]')).to be_present
    expect(row.at_css('input[name$="[note]"]')["value"]).to eq("selected outside first page")
  end

  it "protects remote search endpoints with the admin-only boundary" do
    sign_in_as(external_user)

    get project_search_admin_document_catalogs_path(format: :json), params: { q: "cat" }
    expect(response).to have_http_status(:forbidden)

    get document_search_admin_document_catalogs_path(format: :json), params: { project_id: project.id, q: "getting" }
    expect(response).to have_http_status(:forbidden)
  end

  it "creates a catalog with selected same-project items and ignores out-of-scope rows" do
    sign_in_as(admin)

    expect do
      post admin_document_catalogs_path, params: {
        document_catalog: {
          project_id: project.id,
          name: "公開カタログ",
          description: "customer docs",
          audience_type: "customer",
          visibility_policy: "restricted_external",
          sort_order: 2
        },
        document_catalog_items: {
          "0" => { selected: "1", document_id: document_a.id, sort_order: "1", note: "read first" },
          "1" => { selected: "1", document_id: document_b.id, sort_order: "2", note: "operations" },
          "2" => { selected: "1", document_id: other_document.id, sort_order: "3", note: "outside" },
          "3" => { selected: "0", document_id: document_a.id, sort_order: "4", note: "unselected" },
          "4" => { selected: "1", document_id: "", sort_order: "5", note: "blank" }
        }
      }
    end.to change(DocumentCatalog, :count).by(1).and change(DocumentCatalogItem, :count).by(2)

    expect(response).to redirect_to(admin_document_catalogs_path)

    catalog = DocumentCatalog.find_by!(name: "公開カタログ")
    items = catalog.document_catalog_items.includes(:document).order(:sort_order)

    expect(catalog).to have_attributes(
      project: project,
      audience_type: "customer",
      visibility_policy: "restricted_external",
      sort_order: 2
    )
    expect(items.map(&:document)).to eq([document_a, document_b])
    expect(items.map(&:note)).to eq(["read first", "operations"])
  end

  it "restores selected item input on invalid create rerender" do
    sign_in_as(admin)

    post admin_document_catalogs_path, params: {
      document_catalog: {
        project_id: project.id,
        name: "",
        description: "invalid catalog",
        audience_type: "developer",
        visibility_policy: "public_with_login",
        sort_order: 3
      },
      document_catalog_items: {
        "0" => { selected: "1", document_id: document_a.id, sort_order: "7", note: "keep me" },
        "1" => { selected: "1", document_id: other_document.id, sort_order: "8", note: "outside" }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("カタログ項目")

    row = catalog_item_row_for(document_a)
    expect(row).to be_present
    expect(row.at_css('input[type="checkbox"][checked]')).to be_present
    expect(row.at_css('input[name$="[sort_order]"]')["value"]).to eq("7")
    expect(row.at_css('input[name$="[note]"]')["value"]).to eq("keep me")
    expect(catalog_item_row_for(other_document)).to be_nil
  end

  it "rebuilds existing catalog items from selected same-project rows on update" do
    create(:document_catalog_item, document_catalog: existing_catalog, document: document_a, sort_order: 1, note: "old")

    sign_in_as(admin)

    patch admin_document_catalog_path(existing_catalog), params: {
      document_catalog: {
        project_id: project.id,
        name: "既存カタログ更新",
        description: existing_catalog.description,
        audience_type: "operations",
        visibility_policy: "internal_only",
        sort_order: 4
      },
      document_catalog_items: {
        "0" => { selected: "1", document_id: document_b.id, sort_order: "5", note: "replacement" },
        "1" => { selected: "1", document_id: other_document.id, sort_order: "6", note: "outside ignored" },
        "2" => { selected: "0", document_id: document_a.id, sort_order: "7", note: "unselected" }
      }
    }

    expect(response).to redirect_to(admin_document_catalogs_path)

    items = existing_catalog.reload.document_catalog_items.includes(:document)
    expect(existing_catalog).to have_attributes(
      name: "既存カタログ更新",
      audience_type: "operations",
      visibility_policy: "internal_only",
      sort_order: 4
    )
    expect(items).to contain_exactly(
      have_attributes(document: document_b, sort_order: 5, note: "replacement")
    )
  end

  it "keeps the public catalog viewer behavior unchanged" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: document_a, company: external_user.company, access_level: :view)
    catalog = create(:document_catalog, project:, name: "Customer Viewer", audience_type: :customer, visibility_policy: :restricted_external)
    create(:document_catalog_item, document_catalog: catalog, document: document_a, sort_order: 1, note: "visible note")

    sign_in_as(external_user)

    get project_document_catalogs_path(project)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Customer Viewer")

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Customer Viewer")
    expect(page_text).to include("visible note")
  end
end
