require "rails_helper"

RSpec.describe ExternalVisibilityPreviewHash do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "PREVIEW", name: "Preview Project") }
  let(:viewer) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: viewer)
  end

  def document_with_file(title:, slug:, visibility_policy:, scan_status: :scan_clean, access_level: :view)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, status: :published)
    document.update!(latest_version: version)
    file = create(:document_file, document_version: version, scan_status:)
    create(:document_permission, document:, company:, access_level:) unless visibility_policy == :internal_only
    [document, file]
  end

  it "renders external visibility preview as a hash" do
    visible_document, clean_file = document_with_file(
      title: "Visible",
      slug: "visible",
      visibility_policy: :restricted_external,
      scan_status: :scan_clean,
      access_level: :download
    )
    hidden_document, hidden_file = document_with_file(
      title: "Hidden",
      slug: "hidden",
      visibility_policy: :internal_only,
      scan_status: :scan_clean
    )
    pending_document, pending_file = document_with_file(
      title: "Pending",
      slug: "pending",
      visibility_policy: :restricted_external,
      scan_status: :scan_pending,
      access_level: :download
    )

    hash = described_class.new(project:, viewer:).call

    expect(hash[:viewer]).to include(
      email_address: "client@example.com",
      user_type: "external",
      company_id: company.public_id
    )
    expect(hash[:project]).to include(code: "PREVIEW", name: "Preview Project")
    expect(hash[:summary]).to include(
      total_documents: 3,
      visible_documents: 2,
      hidden_documents: 1,
      downloadable_files: 1,
      blocked_files: 2
    )

    visible_hash = hash[:documents].find { _1[:public_id] == visible_document.public_id }
    expect(visible_hash).to include(title: "Visible", visible: true, project_code: "PREVIEW")
    expect(visible_hash[:downloadable_files]).to contain_exactly(include(public_id: clean_file.public_id))

    hidden_hash = hash[:documents].find { _1[:public_id] == hidden_document.public_id }
    expect(hidden_hash[:visible]).to be(false)
    expect(hidden_hash[:blocked_files]).to contain_exactly(include(public_id: hidden_file.public_id))

    pending_hash = hash[:documents].find { _1[:public_id] == pending_document.public_id }
    expect(pending_hash[:downloadable_files]).to be_empty
    expect(pending_hash[:blocked_files]).to contain_exactly(include(public_id: pending_file.public_id, scan_status: "scan_pending"))
  end

  it "supports a narrower document scope" do
    included_document, = document_with_file(title: "Included", slug: "included", visibility_policy: :restricted_external)
    document_with_file(title: "Excluded", slug: "excluded", visibility_policy: :restricted_external)

    hash = described_class.new(project:, viewer:, scope: Document.where(id: included_document.id)).call

    expect(hash[:summary][:total_documents]).to eq(1)
    expect(hash[:documents].map { _1[:public_id] }).to eq([included_document.public_id])
  end
end
