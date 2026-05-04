require "rails_helper"

RSpec.describe AccessRequestDecider do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:approver) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, visibility_policy: :restricted_external) }

  it "approves project access requests by granting project membership" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :manage)

    expect do
      described_class.new(access_request:, approver:).approve!
    end.to change(ProjectMembership, :count).by(1)

    membership = ProjectMembership.find_by!(project:, user: requester)
    expect(membership.role).to eq("editor")
    expect(access_request.reload).to be_approved
    expect(access_request.approver).to eq(approver)
    expect(access_request.approved_at).to be_present
  end

  it "approves document access requests by granting project membership and document permission" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    expect do
      described_class.new(access_request:, approver:).approve!
    end.to change(ProjectMembership, :count).by(1)
      .and change(DocumentPermission, :count).by(1)

    permission = DocumentPermission.find_by!(document:, company:)
    expect(permission.access_level).to eq("download")
    expect(access_request.reload).to be_approved
  end

  it "does not downgrade existing document permissions" do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :download)
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :view)

    described_class.new(access_request:, approver:).approve!

    expect(DocumentPermission.find_by!(document:, company:).access_level).to eq("download")
  end

  it "rejects pending requests" do
    access_request = create(:access_request, requester:, requestable: project)

    described_class.new(access_request:, approver:).reject!(reason: "Not required")

    expect(access_request.reload).to be_rejected
    expect(access_request.approver).to eq(approver)
    expect(access_request.rejected_at).to be_present
    expect(access_request.rejection_reason).to eq("Not required")
  end

  it "rejects non-internal approvers" do
    external_approver = create(:user, :external, company:)
    access_request = create(:access_request, requester:, requestable: project)

    expect do
      described_class.new(access_request:, approver: external_approver).approve!
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects decisions for non-pending requests" do
    access_request = create(:access_request, requester:, requestable: project)
    described_class.new(access_request:, approver:).reject!(reason: "No")

    expect do
      described_class.new(access_request:, approver:).approve!
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
