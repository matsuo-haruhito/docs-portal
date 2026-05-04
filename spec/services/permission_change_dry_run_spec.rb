require "rails_helper"

RSpec.describe PermissionChangeDryRun do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:viewer) { create(:user, :external, company:) }

  def create_document(title:, slug:, visibility_policy: :restricted_external)
    create(:document, project:, title:, slug:, visibility_policy:)
  end

  it "reports documents gained by a document grant" do
    document = create_document(title: "Manual", slug: "manual")
    create(:project_membership, project:, user: viewer)

    result = described_class.new(
      project:,
      viewers: [viewer],
      grant: { document_ids: [document.id] }
    ).call

    change = result.changes.first
    expect(change.before_documents).to be_empty
    expect(change.after_documents).to eq([document])
    expect(change.gained_documents).to eq([document])
    expect(result.changed_viewers.map(&:viewer)).to eq([viewer])
  end

  it "reports documents lost by a document revoke" do
    document = create_document(title: "Manual", slug: "manual")
    create(:project_membership, project:, user: viewer)
    create(:document_permission, document:, company:, access_level: :view)

    result = described_class.new(
      project:,
      viewers: [viewer],
      revoke: { document_ids: [document.id] }
    ).call

    change = result.changes.first
    expect(change.before_documents).to eq([document])
    expect(change.after_documents).to be_empty
    expect(change.lost_documents).to eq([document])
  end

  it "reports project membership grants without exposing internal-only documents" do
    visible = create_document(title: "Visible", slug: "visible")
    internal = create_document(title: "Internal", slug: "internal", visibility_policy: :internal_only)

    result = described_class.new(
      project:,
      viewers: [viewer],
      grant: { project_membership: true }
    ).call

    change = result.changes.first
    expect(change.gained_documents).to eq([visible])
    expect(change.gained_documents).not_to include(internal)
  end

  it "reports all visible documents lost by project membership revoke" do
    first = create_document(title: "First", slug: "first")
    second = create_document(title: "Second", slug: "second")
    create(:project_membership, project:, user: viewer)
    create(:document_permission, document: first, company:, access_level: :view)
    create(:document_permission, document: second, company:, access_level: :view)

    result = described_class.new(
      project:,
      viewers: [viewer],
      revoke: { project_membership: true }
    ).call

    change = result.changes.first
    expect(change.before_documents).to eq([first, second])
    expect(change.after_documents).to be_empty
    expect(change.lost_documents).to eq([first, second])
  end

  it "supports multiple viewers" do
    document = create_document(title: "Manual", slug: "manual")
    other_viewer = create(:user, :external, company:)
    create(:project_membership, project:, user: viewer)
    create(:project_membership, project:, user: other_viewer)

    result = described_class.new(
      project:,
      viewers: [viewer, other_viewer],
      grant: { document_ids: [document.id] }
    ).call

    expect(result.changes.map(&:viewer)).to eq([viewer, other_viewer])
    expect(result.gained_documents).to eq([document])
  end
end
