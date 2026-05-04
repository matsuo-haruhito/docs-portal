require "rails_helper"

RSpec.describe AiContextExportPlanHash do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AIPLAN", name: "AI Plan Project") }
  let(:viewer) { create(:user, :external, company:, email_address: "client@example.com") }

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

  it "renders an AI context export plan as a hash" do
    visible_document, visible_version = create_document_with_version(title: "Visible", slug: "visible")
    hidden_document, hidden_version = create_document_with_version(title: "Hidden", slug: "hidden", visibility_policy: :internal_only)

    hash = described_class.new(project:, viewer:).call

    expect(hash[:project]).to include(code: "AIPLAN", name: "AI Plan Project")
    expect(hash[:viewer]).to include(email_address: "client@example.com", user_type: "external", company_id: company.public_id)
    expect(hash[:summary]).to include(
      total_documents: 2,
      included_documents: 1,
      excluded_documents: 1,
      included_public_ids: [visible_document.public_id]
    )

    included_item = hash[:items].find { _1[:document][:public_id] == visible_document.public_id }
    excluded_item = hash[:items].find { _1[:document][:public_id] == hidden_document.public_id }

    expect(included_item).to include(included: true, reason: "viewable")
    expect(included_item[:document_version]).to include(public_id: visible_version.public_id, source_relative_path: "docs/visible.md")
    expect(excluded_item).to include(included: false, reason: "not_viewable")
    expect(excluded_item[:document_version]).to include(public_id: hidden_version.public_id, source_relative_path: "docs/hidden.md")
  end

  it "supports a narrower document scope" do
    included_document, = create_document_with_version(title: "Included", slug: "included")
    create_document_with_version(title: "Excluded", slug: "excluded")

    hash = described_class.new(project:, viewer:, scope: Document.where(id: included_document.id)).call

    expect(hash[:summary]).to include(total_documents: 1, included_documents: 1, excluded_documents: 0)
    expect(hash[:items].map { _1[:document][:public_id] }).to eq([included_document.public_id])
  end

  it "renders nil document_version when latest version is missing" do
    document = create(:document, project:, title: "No Version", slug: "no-version", visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)

    hash = described_class.new(project:, viewer:).call

    item = hash[:items].find { _1[:document][:public_id] == document.public_id }
    expect(item[:included]).to be(true)
    expect(item[:document_version]).to be_nil
  end
end
