require "rails_helper"

RSpec.describe DocumentCatalogHash do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "CAT") }
  let(:viewer) { create(:user, :external, company:) }

  before do
    create(:project_membership, project:, user: viewer)
  end

  it "renders only visible catalog items as a hash" do
    visible_document = create(:document, project:, title: "Visible", slug: "visible", visibility_policy: :restricted_external)
    hidden_document = create(:document, project:, title: "Hidden", slug: "hidden", visibility_policy: :internal_only)
    version = create(:document_version, document: visible_document, version_label: "v1")
    visible_document.update!(latest_version: version)
    create(:document_permission, document: visible_document, company:, access_level: :view)
    catalog = create(:document_catalog, project:, name: "Customer", audience_type: :customer, visibility_policy: :restricted_external)
    create(:document_catalog_item, document_catalog: catalog, document: visible_document, sort_order: 2, note: "Read first")
    create(:document_catalog_item, document_catalog: catalog, document: hidden_document, sort_order: 1)

    hash = described_class.new(document_catalog: catalog, viewer:).call

    expect(hash[:catalog]).to include(name: "Customer", audience_type: "customer", visibility_policy: "restricted_external", project_code: "CAT")
    expect(hash[:viewer]).to include(public_id: viewer.public_id, user_type: "external", company_id: company.public_id)
    expect(hash[:summary]).to include(total_items: 2, visible_items: 1, hidden_items: 1)
    expect(hash[:items].size).to eq(1)
    expect(hash[:items].first).to include(sort_order: 2, note: "Read first")
    expect(hash[:items].first[:document]).to include(
      public_id: visible_document.public_id,
      title: "Visible",
      slug: "visible",
      latest_version_id: version.public_id
    )
  end
end
