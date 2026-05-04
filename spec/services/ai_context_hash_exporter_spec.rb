require "rails_helper"

RSpec.describe AiContextHashExporter do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AIHASH", name: "AI Hash Project") }
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

  it "exports compact hash for documents visible to the viewer" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    hash = described_class.new(project:, viewer:, mode: :compact).call

    expect(hash[:project]).to include(code: "AIHASH", name: "AI Hash Project")
    expect(hash[:viewer]).to include(email_address: "client@example.com", user_type: "external", company_id: company.public_id)
    expect(hash[:mode]).to eq(:compact)
    expect(hash[:summary]).to include(document_count: 1, mode: :compact, exported_public_ids: [visible.public_id])
    expect(hash[:documents].size).to eq(1)
    expect(hash[:documents].first).to include(
      public_id: visible.public_id,
      title: "Visible Manual",
      slug: "visible",
      summary: "Visible body text."
    )
    expect(hash[:documents].first).not_to have_key(:body_text)
  end

  it "exports full hash with body text" do
    document = create_exportable_document(title: "Full Manual", slug: "full", body: "Full body text for AI.")

    hash = described_class.new(project:, viewer:, mode: :full).call

    expect(hash[:mode]).to eq(:full)
    expect(hash[:documents].first).to include(public_id: document.public_id, body_text: "Full body text for AI.")
    expect(hash[:documents].first).not_to have_key(:summary)
  end

  it "supports a narrower document scope" do
    included = create_exportable_document(title: "Included", slug: "included", body: "Included body.")
    create_exportable_document(title: "Excluded", slug: "excluded", body: "Excluded body.")

    hash = described_class.new(project:, viewer:, scope: Document.where(id: included.id)).call

    expect(hash[:summary][:document_count]).to eq(1)
    expect(hash[:documents].map { _1[:public_id] }).to eq([included.public_id])
  end

  it "renders no documents when none are exportable" do
    create_exportable_document(title: "Internal", slug: "internal", body: "Secret", visibility_policy: :internal_only)

    hash = described_class.new(project:, viewer:).call

    expect(hash[:summary]).to include(document_count: 0, exported_public_ids: [])
    expect(hash[:documents]).to eq([])
  end

  it "rejects unsupported modes" do
    expect do
      described_class.new(project:, viewer:, mode: :unknown).call
    end.to raise_error(ArgumentError, /unsupported mode/)
  end
end
