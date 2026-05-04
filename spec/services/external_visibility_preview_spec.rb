require "rails_helper"

RSpec.describe ExternalVisibilityPreview do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:viewer) { create(:user, :external, company:) }

  before do
    create(:project_membership, project:, user: viewer)
  end

  def document_with_file(title:, slug:, visibility_policy:, scan_status: :scan_clean)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, status: :published)
    document.update!(latest_version: version)
    file = create(:document_file, document_version: version, scan_status:)
    [document, file]
  end

  it "summarizes visible and hidden documents for an external viewer" do
    visible_document, = document_with_file(title: "Visible", slug: "visible", visibility_policy: :restricted_external)
    hidden_document, = document_with_file(title: "Hidden", slug: "hidden", visibility_policy: :internal_only)
    create(:document_permission, document: visible_document, company:, access_level: :view)

    result = described_class.new(project:, viewer:).call

    expect(result.visible_documents).to eq([visible_document])
    expect(result.hidden_documents).to eq([hidden_document])
  end

  it "separates downloadable and blocked files" do
    visible_document, clean_file = document_with_file(title: "Clean", slug: "clean", visibility_policy: :restricted_external, scan_status: :scan_clean)
    _, pending_file = document_with_file(title: "Pending", slug: "pending", visibility_policy: :restricted_external, scan_status: :scan_pending)
    create(:document_permission, document: visible_document, company:, access_level: :download)
    create(:document_permission, document: pending_file.document_version.document, company:, access_level: :download)

    result = described_class.new(project:, viewer:).call

    expect(result.downloadable_files).to include(clean_file)
    expect(result.blocked_files).to include(pending_file)
  end

  it "marks files on hidden documents as blocked" do
    hidden_document, hidden_file = document_with_file(title: "Hidden", slug: "hidden", visibility_policy: :internal_only)

    result = described_class.new(project:, viewer:).call

    document_result = result.document_results.find { _1.document == hidden_document }
    expect(document_result).not_to be_visible
    expect(document_result.downloadable_files).to be_empty
    expect(document_result.blocked_files).to eq([hidden_file])
  end

  it "supports a narrower document scope" do
    included_document, = document_with_file(title: "Included", slug: "included", visibility_policy: :restricted_external)
    excluded_document, = document_with_file(title: "Excluded", slug: "excluded", visibility_policy: :restricted_external)
    create(:document_permission, document: included_document, company:, access_level: :view)
    create(:document_permission, document: excluded_document, company:, access_level: :view)

    result = described_class.new(project:, viewer:, scope: Document.where(id: included_document.id)).call

    expect(result.document_results.map(&:document)).to eq([included_document])
  end
end
