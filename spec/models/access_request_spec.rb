require "rails_helper"

RSpec.describe AccessRequest, type: :model do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }

  it "allows a pending project access request" do
    request = build(:access_request, requester:, project:, document: nil, reason: "Need project access")

    expect(request).to be_valid
  end

  it "allows a pending document access request" do
    request = build(:access_request, requester:, project: nil, document:, reason: "Need document access")

    expect(request).to be_valid
  end

  it "requires exactly one request target" do
    no_target = build(:access_request, requester:, project: nil, document: nil)
    both_targets = build(:access_request, requester:, project:, document:)

    expect(no_target).not_to be_valid
    expect(both_targets).not_to be_valid
    expect(no_target.errors[:base]).to be_present
    expect(both_targets.errors[:base]).to be_present
  end

  it "requires internal approvers" do
    request = build(:access_request, requester:, project:, approver: external_user)

    expect(request).not_to be_valid
    expect(request.errors[:approver]).to be_present
  end

  it "requires approval metadata for approved requests" do
    request = build(:access_request, requester:, project:, status: :approved, approver: nil, approved_at: nil)

    expect(request).not_to be_valid
    expect(request.errors[:approver]).to be_present
    expect(request.errors[:approved_at]).to be_present
  end

  it "requires rejection metadata for rejected requests" do
    request = build(:access_request, requester:, project:, status: :rejected, approver: internal_user, rejected_at: Time.current, rejection_reason: "Not needed")

    expect(request).to be_valid
  end

  it "rejects stale resolution metadata for pending requests" do
    request = build(:access_request, requester:, project:, status: :pending, approved_at: Time.current)

    expect(request).not_to be_valid
    expect(request.errors[:approved_at]).to be_present
  end

  it "uses public_id for routes" do
    request = create(:access_request, requester:, project:)

    expect(request.to_param).to eq(request.public_id)
  end
end
