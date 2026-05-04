require "rails_helper"

RSpec.describe AiContextMarkdownExporter do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:viewer) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: viewer)
  end

  def create_exportable_document(title:, slug:, body:, visibility_policy: :restricted_external)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(
      :document_version,
      document:,
      version_label: "v1",
      source_relative_path: "docs/#{slug}.md",
      search_body_text: body
    )
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :view) unless visibility_policy == :internal_only
    document
  end

  it "exports compact markdown for documents visible to the viewer" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    markdown = described_class.new(project:, viewer:, mode: :compact).call

    expect(markdown).to include("# Project: AI Context Project")
    expect(markdown).to include("- code: AICTX")
    expect(markdown).to include("- export_mode: compact")
    expect(markdown).to include("- viewer: client@example.com")
    expect(markdown).to include("- document_count: 1")
    expect(markdown).to include("### Visible Manual")
    expect(markdown).to include("- public_id: #{visible.public_id}")
    expect(markdown).to include("- source_path: docs/visible.md")
    expect(markdown).to include("- summary: Visible body text.")
    expect(markdown).not_to include("Internal Note")
    expect(markdown).not_to include("Secret body text")
  end

  it "exports full markdown with body text" do
    create_exportable_document(title: "Full Manual", slug: "full", body: "Full body text for AI.")

    markdown = described_class.new(project:, viewer:, mode: :full).call

    expect(markdown).to include("- export_mode: full")
    expect(markdown).to include("### Full Manual")
    expect(markdown).to include("Full body text for AI.")
  end

  it "supports a narrower document scope" do
    included = create_exportable_document(title: "Included", slug: "included", body: "Included body.")
    create_exportable_document(title: "Excluded", slug: "excluded", body: "Excluded body.")

    markdown = described_class.new(project:, viewer:, scope: Document.where(id: included.id)).call

    expect(markdown).to include("### Included")
    expect(markdown).not_to include("### Excluded")
  end

  it "renders an empty state when there are no exportable documents" do
    create_exportable_document(title: "Internal", slug: "internal", body: "Secret", visibility_policy: :internal_only)

    markdown = described_class.new(project:, viewer:).call

    expect(markdown).to include("- document_count: 0")
    expect(markdown).to include("No exportable documents.")
  end

  it "rejects unsupported modes" do
    expect do
      described_class.new(project:, viewer:, mode: :unknown).call
    end.to raise_error(ArgumentError, /unsupported mode/)
  end
end
