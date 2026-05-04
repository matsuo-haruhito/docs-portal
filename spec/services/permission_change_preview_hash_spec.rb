require "rails_helper"

RSpec.describe PermissionChangePreviewHash do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "PERM", name: "Permission Project") }
  let(:viewer) { create(:user, :external, company:, email_address: "client@example.com") }

  def create_document(title:, slug:, visibility_policy: :restricted_external)
    create(:document, project:, title:, slug:, visibility_policy:)
  end

  it "renders document grant impact as a hash" do
    document = create_document(title: "Manual", slug: "manual")
    create(:project_membership, project:, user: viewer)

    hash = described_class.new(
      project:,
      viewers: [viewer],
      grant_document_ids: [document.id]
    ).call

    expect(hash[:project]).to include(code: "PERM", name: "Permission Project")
    expect(hash[:summary]).to include(
      total_viewers: 1,
      changed_viewers: 1,
      gained_documents: 1,
      lost_documents: 0
    )

    viewer_hash = hash[:viewers].first
    expect(viewer_hash).to include(
      email_address: "client@example.com",
      changed: true,
      before_visible_count: 0,
      after_visible_count: 1
    )
    expect(viewer_hash[:gained_documents]).to contain_exactly(include(title: "Manual", slug: "manual"))
    expect(viewer_hash[:lost_documents]).to be_empty
  end

  it "renders document revoke impact as a hash" do
    document = create_document(title: "Manual", slug: "manual")
    create(:project_membership, project:, user: viewer)
    create(:document_permission, document:, company:, access_level: :view)

    hash = described_class.new(
      project:,
      viewers: [viewer],
      revoke_document_ids: [document.id]
    ).call

    viewer_hash = hash[:viewers].first
    expect(viewer_hash[:before_visible_count]).to eq(1)
    expect(viewer_hash[:after_visible_count]).to eq(0)
    expect(viewer_hash[:lost_documents]).to contain_exactly(include(public_id: document.public_id))
  end

  it "renders project membership grant without exposing internal-only documents" do
    visible = create_document(title: "Visible", slug: "visible")
    internal = create_document(title: "Internal", slug: "internal", visibility_policy: :internal_only)

    hash = described_class.new(
      project:,
      viewers: [viewer],
      grant_project_membership: true
    ).call

    gained_titles = hash[:viewers].first[:gained_documents].map { _1[:title] }
    expect(gained_titles).to eq(["Visible"])
    expect(gained_titles).not_to include(internal.title)
  end

  it "renders project membership revoke impact" do
    first = create_document(title: "First", slug: "first")
    second = create_document(title: "Second", slug: "second")
    create(:project_membership, project:, user: viewer)
    create(:document_permission, document: first, company:, access_level: :view)
    create(:document_permission, document: second, company:, access_level: :view)

    hash = described_class.new(
      project:,
      viewers: [viewer],
      revoke_project_membership: true
    ).call

    expect(hash[:summary]).to include(changed_viewers: 1, gained_documents: 0, lost_documents: 2)
    expect(hash[:viewers].first[:lost_documents].map { _1[:title] }).to eq(["First", "Second"])
  end

  it "supports multiple viewers and scope filtering" do
    included = create_document(title: "Included", slug: "included")
    excluded = create_document(title: "Excluded", slug: "excluded")
    other_viewer = create(:user, :external, company:)
    create(:project_membership, project:, user: viewer)
    create(:project_membership, project:, user: other_viewer)

    hash = described_class.new(
      project:,
      viewers: [viewer, other_viewer],
      grant_document_ids: [included.id, excluded.id],
      scope: Document.where(id: included.id)
    ).call

    expect(hash[:summary]).to include(total_viewers: 2, changed_viewers: 2, gained_documents: 1)
    expect(hash[:viewers].flat_map { _1[:gained_documents] }.map { _1[:public_id] }.uniq).to eq([included.public_id])
  end
end
