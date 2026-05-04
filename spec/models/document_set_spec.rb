require "rails_helper"

RSpec.describe DocumentSet, type: :model do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }

  before do
    create(:project_membership, project:, user: external_user)
  end

  it "orders document sets by sort order and name" do
    later = create(:document_set, project:, name: "B", sort_order: 2)
    earlier = create(:document_set, project:, name: "A", sort_order: 1)

    expect(described_class.where(id: [later.id, earlier.id]).ordered).to eq([earlier, later])
  end

  it "is visible to internal users regardless of visibility policy" do
    document_set = create(:document_set, project:, visibility_policy: :internal_only)

    expect(document_set.viewable_by?(internal_user)).to be(true)
  end

  it "hides internal-only document sets from external users" do
    document_set = create(:document_set, project:, visibility_policy: :internal_only)

    expect(document_set.viewable_by?(external_user)).to be(false)
  end

  it "shows restricted document sets to external users who can view the project" do
    document_set = create(:document_set, project:, visibility_policy: :restricted_external)

    expect(document_set.viewable_by?(external_user)).to be(true)
  end

  it "returns only readable items for the user" do
    visible_document = create(:document, project:, title: "Visible", slug: "visible", visibility_policy: :restricted_external)
    hidden_document = create(:document, project:, title: "Hidden", slug: "hidden", visibility_policy: :internal_only)
    create(:document_permission, document: visible_document, company:, access_level: :view)
    document_set = create(:document_set, project:, visibility_policy: :restricted_external)
    visible_item = create(:document_set_item, document_set:, document: visible_document, sort_order: 2)
    create(:document_set_item, document_set:, document: hidden_document, sort_order: 1)

    expect(document_set.visible_items_for(external_user)).to eq([visible_item])
  end

  it "uses public_id for routes" do
    document_set = create(:document_set, project:)

    expect(document_set.to_param).to eq(document_set.public_id)
  end
end
