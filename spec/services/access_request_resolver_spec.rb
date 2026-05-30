require "rails_helper"

RSpec.describe AccessRequestResolver do
  let(:approver) { create(:user, :internal) }
  let(:external_approver) { create(:user, :external) }
  let(:requester) { create(:user, :external) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }

  describe "#approve!" do
    context "when the requestable is a project" do
      let(:access_request) { create(:access_request, requester:, requestable: project, requested_access_level: :view) }

      it "grants the requester a viewer project membership" do
        result = nil

        expect do
          result = described_class.new(access_request:, approver:).approve!
        end.to change(ProjectMembership, :count).by(1)

        membership = ProjectMembership.find_by!(project:, user: requester)
        expect(membership).to be_viewer
        expect(result.granted_record).to eq(membership)
        expect(access_request.reload).to be_approved
        expect(access_request.approver).to eq(approver)
        expect(access_request.approved_at).to be_present
      end
    end

    context "when the requestable is a document" do
      let(:access_request) { create(:access_request, requester:, requestable: document, requested_access_level: :download) }

      it "grants the requested download permission on the document" do
        result = nil

        expect do
          result = described_class.new(access_request:, approver:).approve!
        end.to change(DocumentPermission, :count).by(1)

        permission = DocumentPermission.find_by!(document:, user: requester)
        expect(permission).to be_download
        expect(result.granted_record).to eq(permission)
        expect(access_request.reload).to be_approved
      end
    end

    context "when the requestable is a document file" do
      let(:document_version) { create(:document_version, document:) }
      let(:document_file) { create(:document_file, document_version:) }
      let(:access_request) { create(:access_request, requester:, requestable: document_file, requested_access_level: :download) }

      it "grants permission on the parent document" do
        result = nil

        expect do
          result = described_class.new(access_request:, approver:).approve!
        end.to change(DocumentPermission, :count).by(1)

        permission = DocumentPermission.find_by!(document:, user: requester)
        expect(permission).to be_download
        expect(result.granted_record).to eq(permission)
        expect(access_request.reload).to be_approved
      end
    end

    context "when the requested access level is manage" do
      let(:access_request) { create(:access_request, requester:, requestable: document, requested_access_level: :manage) }

      it "documents the current document permission fallback without deciding the product policy" do
        described_class.new(access_request:, approver:).approve!

        permission = DocumentPermission.find_by!(document:, user: requester)
        expect(permission).to be_view
      end
    end

    it "rejects non-internal approvers before granting access" do
      access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

      expect do
        described_class.new(access_request:, approver: external_approver).approve!
      end.to raise_error(ApplicationError::Forbidden, "approver must be internal")

      expect(DocumentPermission.where(document:, user: requester)).to be_empty
      expect(access_request.reload).to be_pending
    end

    it "rejects terminal requests before granting access" do
      access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)
      access_request.update!(status: :approved, approver:, approved_at: Time.current)

      expect do
        described_class.new(access_request:, approver:).approve!
      end.to raise_error(ApplicationError::BadRequest, "access request is not pending")

      expect(DocumentPermission.where(document:, user: requester)).to be_empty
      expect(access_request.reload).to be_approved
    end
  end

  describe "#reject!" do
    it "rejects a pending request" do
      access_request = create(:access_request, requester:, requestable: project)

      result = described_class.new(access_request:, approver:).reject!(reason: "Not needed")

      expect(result).not_to be_granted
      expect(access_request.reload).to be_rejected
      expect(access_request.rejection_reason).to eq("Not needed")
      expect(access_request.rejected_at).to be_present
    end

    it "rejects terminal requests" do
      access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
      access_request.update!(status: :approved, approver:, approved_at: Time.current)

      expect do
        described_class.new(access_request:, approver:).reject!(reason: "No longer needed")
      end.to raise_error(ApplicationError::BadRequest, "access request is not pending")

      expect(access_request.reload).to be_approved
    end
  end

  describe "#cancel!" do
    it "cancels a pending request" do
      access_request = create(:access_request, requester:, requestable: project)

      result = described_class.new(access_request:, approver:).cancel!

      expect(result).not_to be_granted
      expect(access_request.reload).to be_cancelled
      expect(access_request.cancelled_at).to be_present
    end

    it "rejects terminal requests" do
      access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
      access_request.update!(status: :rejected, approver:, rejected_at: Time.current, rejection_reason: "Rejected")

      expect do
        described_class.new(access_request:, approver:).cancel!
      end.to raise_error(ApplicationError::BadRequest, "access request is not pending")

      expect(access_request.reload).to be_rejected
    end
  end
end
