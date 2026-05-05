require "rails_helper"

RSpec.describe "Document catalogs", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "CATALOG", name: "Catalog Project") }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }

  before do
    create(:project_membership, project:, user: external_user)
  end

  it "lists viewable catalogs for the project" do
    visible = create(:document_catalog, project:, name: "Customer Pack", audience_type: :customer, visibility_policy: :restricted_external)
    create(:document_catalog, project:, name: "Internal Pack", visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_document_catalogs_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書カタログ")
    expect(response.body).to include("Customer Pack")
    expect(response.body).not_to include("Internal Pack")
    expect(response.body).to include(project_document_catalog_path(project, visible))
  end

  it "shows only visible items in a catalog" do
    visible_document = create(:document, project:, title: "Visible Manual", slug: "visible-manual", visibility_policy: :restricted_external)
    hidden_document = create(:document, project:, title: "Internal Manual", slug: "internal-manual", visibility_policy: :internal_only)
    visible_version = create(:document_version, document: visible_document, version_label: "v1.0.0", status: :published)
    visible_document.update!(latest_version: visible_version)
    create(:document_permission, document: visible_document, company:, access_level: :view)

    catalog = create(:document_catalog, project:, name: "Customer Pack", visibility_policy: :restricted_external)
    create(:document_catalog_item, document_catalog: catalog, document: hidden_document, sort_order: 1, note: "internal")
    create(:document_catalog_item, document_catalog: catalog, document: visible_document, sort_order: 2, note: "read first")

    sign_in_as(external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Customer Pack")
    expect(response.body).to include("Visible Manual")
    expect(response.body).to include("read first")
    expect(response.body).not_to include("Internal Manual")
    expect(response.body).not_to include("internal")
  end

  it "forbids external users from internal-only catalogs" do
    catalog = create(:document_catalog, project:, visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:forbidden)
  end

  it "allows internal users to view internal-only catalogs" do
    document = create(:document, project:, title: "Internal Manual", slug: "internal-manual", visibility_policy: :internal_only)
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    catalog = create(:document_catalog, project:, name: "Internal Pack", visibility_policy: :internal_only)
    create(:document_catalog_item, document_catalog: catalog, document:, sort_order: 1)

    sign_in_as(internal_user)

    get project_document_catalog_path(project, catalog)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Internal Pack")
    expect(response.body).to include("Internal Manual")
  end
end
