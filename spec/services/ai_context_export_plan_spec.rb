require "rails_helper"

RSpec.describe AiContextExportPlan do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:viewer) { create(:user, :external, company:) }

  before do
    create(:project_membership, project:, user: viewer)
  end

  def create_document_with_version(title:, slug:, visibility_policy: :restricted_external)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md")
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :view) unless visibility_policy == :internal_only
    [document, version]
  end

  it "plans included and excluded documents for AI context export" do
    visible_document, visible_version = create_document_with_version(title: "Visible", slug: "visible")
    hidden_document, hidden_version = create_document_with_version(title: "Hidden", slug: "hidden", visibility_policy: :internal_only)

    result = described_class.new(project:, viewer:).call

    expect(result.project).to eq(project)
    expect(result.viewer).to eq(viewer)
    expect(result.included_documents).to eq([visible_document])
    expect(result.excluded_documents).to eq([hidden_document])

    included_item = result.included_items.first
    excluded_item = result.excluded_items.first
    expect(included_item.document_version).to eq(visible_version)
    expect(included_item.reason).to eq("viewable")
    expect(excluded_item.document_version).to eq(hidden_version)
    expect(excluded_item.reason).to eq("not_viewable")
  end

  it "supports a narrower document scope" do
    included_document, = create_document_with_version(title: "Included", slug: "included")
    create_document_with_version(title: "Excluded", slug: "excluded")

    result = described_class.new(project:, viewer:, scope: Document.where(id: included_document.id)).call

    expect(result.items.map(&:document)).to eq([included_document])
  end

  it "orders items by title and id" do
    second, = create_document_with_version(title: "B", slug: "b")
    first, = create_document_with_version(title: "A", slug: "a")

    result = described_class.new(project:, viewer:).call

    expect(result.items.map(&:document)).to eq([first, second])
  end
end
