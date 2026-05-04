require "rails_helper"

RSpec.describe AiContextExporter do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project", description: "Project description") }
  let(:internal_user) { create(:user, :internal, email_address: "internal@example.com") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  def create_document_with_latest_version(title:, slug:, body:, visibility_policy: :restricted_external)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      source_relative_path: "docs/#{slug}.md",
      search_body_text: body
    )
    document.update!(latest_version: version)
    document
  end

  it "exports compact project metadata and readable document metadata" do
    document = create_document_with_latest_version(title: "Manual", slug: "manual", body: "Full manual body")

    markdown = described_class.new(project:, user: internal_user).call

    expect(markdown).to include("# Project: AI Context Project")
    expect(markdown).to include("- code: AICTX")
    expect(markdown).to include("- exported_for: internal@example.com")
    expect(markdown).to include("### Manual")
    expect(markdown).to include("- source_path: docs/manual.md")
    expect(markdown).not_to include("Full manual body")
    expect(document.latest_version).to be_present
  end

  it "includes body text in full mode" do
    create_document_with_latest_version(title: "Manual", slug: "manual", body: "Full manual body")

    markdown = described_class.new(project:, user: internal_user, mode: :full).call

    expect(markdown).to include("#### Body")
    expect(markdown).to include("Full manual body")
  end

  it "excludes documents that are not readable by the user" do
    visible = create_document_with_latest_version(title: "Visible", slug: "visible", body: "Visible body")
    hidden = create_document_with_latest_version(title: "Hidden", slug: "hidden", body: "Hidden body", visibility_policy: :internal_only)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: visible, company:, access_level: :view)

    markdown = described_class.new(project:, user: external_user, mode: :full).call

    expect(markdown).to include("### Visible")
    expect(markdown).to include("Visible body")
    expect(markdown).not_to include("### Hidden")
    expect(markdown).not_to include("Hidden body")
    expect(hidden.viewable_by?(external_user)).to be(false)
  end

  it "supports a narrower document scope" do
    included = create_document_with_latest_version(title: "Included", slug: "included", body: "Included body")
    create_document_with_latest_version(title: "Excluded", slug: "excluded", body: "Excluded body")

    markdown = described_class.new(
      project:,
      user: internal_user,
      mode: :full,
      scope: Document.where(id: included.id)
    ).call

    expect(markdown).to include("### Included")
    expect(markdown).not_to include("### Excluded")
  end

  it "rejects unsupported export modes" do
    exporter = described_class.new(project:, user: internal_user, mode: :unknown)

    expect { exporter.call }.to raise_error(ArgumentError, /unsupported AI context export mode/)
  end
end
