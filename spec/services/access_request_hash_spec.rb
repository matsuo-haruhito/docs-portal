require "rails_helper"

RSpec.describe AccessRequestHash do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client", email_address: "client@example.com") }
  let(:approver) { create(:user, :internal, name: "Admin", email_address: "admin@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }

  it "renders a project access request" do
    request = create(:access_request, requester:, approver:, requestable: project, status: :approved, approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    hash = described_class.new(request).call

    expect(hash).to include(status: "approved", requested_access_level: "view", reason: "Need access for project work.")
    expect(hash[:requester]).to include(name: "Client", email_address: "client@example.com", company_id: company.public_id)
    expect(hash[:approver]).to include(name: "Admin", email_address: "admin@example.com")
    expect(hash[:requestable]).to include(type: "Project", public_id: project.public_id, code: "REQ", name: "Request Project")
    expect(hash[:approved_at]).to eq("2026-05-01T12:00:00Z")
  end

  it "renders a document file access request target" do
    document = create(:document, project:, title: "Manual")
    version = create(:document_version, document:)
    file = create(:document_file, document_version: version, file_name: "manual.pdf")
    request = create(:access_request, requester:, requestable: file, requested_access_level: :download)

    hash = described_class.new(request).call

    expect(hash[:requestable]).to include(
      type: "DocumentFile",
      public_id: file.public_id,
      file_name: "manual.pdf",
      document_id: document.public_id,
      document_title: "Manual"
    )
  end
end
