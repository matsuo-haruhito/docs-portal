require "rails_helper"

RSpec.describe AccessRequestResolver do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:approver) { create(:user, :internal) }
  let(:project) { create(:project) }

  it "approves a project request by creating a project membership" do
    request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    result = described_class.new(access_request: request, approver:).approve!

    expect(request.reload).to be_approved
    expect(request.approver).to eq(approver)
    expect(request.approved_at).to be_present
    expect(result.granted_record).to be_a(ProjectMembership)
    expect(ProjectMembership.exists?(project:, user: requester, role: :viewer)).to be(true)
  end

  it "approves a document request by creating a user document permission" do
    document = create(:document, project:)
    request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    result = described_class.new(access_request: request, approver:).approve!

    permission = DocumentPermission.find_by!(document:, user: requester)
    expect(result.granted_record).to eq(permission)
    expect(permission).to be_download
  end

  it "approves a document file request by granting access to its document" do
    document = create(:document, project:)
    version = create(:document_version, document:)
    file = create(:document_file, document_version: version)
    request = create(:access_request, requester:, requestable: file, requested_access_level: :download)

    described_class.new(access_request: request, approver:).approve!

    permission = DocumentPermission.find_by!(document:, user: requester)
    expect(permission).to be_download
  end

  it "rejects a pending request" do
    request = create(:access_request, requester:, requestable: project)

    result = described_class.new(access_request: request, approver:).reject!(reason: "Not needed")

    expect(result).not_to be_granted
    expect(request.reload).to be_rejected
    expect(request.rejection_reason).to eq("Not needed")
    expect(request.rejected_at).to be_present
  end

  it "cancels a pending request" do
    request = create(:access_request, requester:, requestable: project)

    described_class.new(access_request: request, approver:).cancel!

    expect(request.reload).to be_cancelled
    expect(request.cancelled_at).to be_present
  end

  it "does not allow non-internal approvers" do
    request = create(:access_request, requester:, requestable: project)
    external_approver = create(:user, :external, company:)

    expect do
      described_class.new(access_request: request, approver: external_approver).approve!
    end.to raise_error(ApplicationError::Forbidden)
  end
end
