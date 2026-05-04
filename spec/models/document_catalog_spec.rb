require "rails_helper"

RSpec.describe DocumentCatalog, type: :model do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }

  before do
    create(:project_membership, project:, user: external_user)
  end

  it "orders catalogs by sort order and name" do
    later = create(:document_catalog, project:, name: "B", sort_order: 2)
    earlier = create(:document_catalog, project:, name: "A", sort_order: 1)

    expect(described_class.where(id: [later.id, earlier.id]).ordered).to eq([earlier, later])
  end

  it "is visible to internal users regardless of visibility policy" do
    catalog = create(:document_catalog, project:, visibility_policy: :internal_only)

    expect(catalog.viewable_by?(internal_user)).to be(true)
  end

  it "hides internal-only catalogs from external users" do
    catalog = create(:document_catalog, project:, visibility_policy: :internal_only)

    expect(catalog.viewable_by?(external_user)).to be(false)
  end

  it "shows restricted catalogs to external users who can view the project" do
    catalog = create(:document_catalog, project:, visibility_policy: :restricted_external)

    expect(catalog.viewable_by?(external_user)).to be(true)
  end

  it "returns only readable items for the viewer" do
    visible_document = create(:document, project:, title: "Visible", slug: "visible", visibility_policy: :restricted_external)
    hidden_document = create(:document, project:, title: "Hidden", slug: "hidden", visibility_policy: :internal_only)
    create(:document_permission, document: visible_document, company:, access_level: :view)
    catalog = create(:document_catalog, project:, visibility_policy: :restricted_external)
    visible_item = create(:document_catalog_item, document_catalog: catalog, document: visible_document, sort_order: 2)
    create(:document_catalog_item, document_catalog: catalog, document: hidden_document, sort_order: 1)

    expect(catalog.visible_items_for(external_user)).to eq([visible_item])
  end

  it "does not allow documents from another project" do
    other_document = create(:document)
    catalog = create(:document_catalog, project:)
    item = build(:document_catalog_item, document_catalog: catalog, document: other_document)

    expect(item).not_to be_valid
    expect(item.errors[:document]).to be_present
  end

  it "uses public_id for routes" do
    catalog = create(:document_catalog, project:)

    expect(catalog.to_param).to eq(catalog.public_id)
  end
end
