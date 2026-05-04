require "rails_helper"

RSpec.describe AccessRequest, type: :model do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }
  let(:document_file) { create(:document_file, document_version: version) }

  it "allows pending requests for supported targets" do
    expect(build(:access_request, requester:, requestable: project)).to be_valid
    expect(build(:access_request, requester:, requestable: document)).to be_valid
    expect(build(:access_request, requester:, requestable: document_file)).to be_valid
  end

  it "requires active requesters" do
    inactive_user = create(:user, :external, company:, active: false)
    request = build(:access_request, requester: inactive_user, requestable: project)

    expect(request).not_to be_valid
    expect(request.errors[:requester]).to be_present
  end

  it "requires internal approvers" do
    request = build(:access_request, requester:, requestable: project, approver: external_user)

    expect(request).not_to be_valid
    expect(request.errors[:approver]).to be_present
  end

  it "requires approval metadata for approved requests" do
    request = build(:access_request, requester:, requestable: project, status: :approved, approver: nil, approved_at: nil)

    expect(request).not_to be_valid
    expect(request.errors[:approver]).to be_present
    expect(request.errors[:approved_at]).to be_present
  end

  it "allows rejected requests with rejection metadata" do
    request = build(:access_request, requester:, requestable: project, status: :rejected, approver: internal_user, rejected_at: Time.current, rejection_reason: "Not needed")

    expect(request).to be_valid
  end

  it "rejects stale resolution metadata for pending requests" do
    request = build(:access_request, requester:, requestable: project, status: :pending, approved_at: Time.current)

    expect(request).not_to be_valid
    expect(request.errors[:approved_at]).to be_present
  end

  it "uses public_id for routes" do
    request = create(:access_request, requester:, requestable: project)

    expect(request.to_param).to eq(request.public_id)
  end
end
