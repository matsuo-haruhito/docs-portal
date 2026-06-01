require "rails_helper"

RSpec.describe DocumentApprovalRequest, type: :model do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "is valid for a requester who can view the document" do
    request = described_class.new(document:, requester:, title: "確認してください")

    expect(request).to be_valid
  end

  it "rejects requesters who cannot view the document" do
    hidden_requester = create(:user, :external, company: create(:company))
    request = described_class.new(document:, requester: hidden_requester, title: "確認してください")

    expect(request).not_to be_valid
    expect(request.errors[:requester]).to be_present
  end

  it "keeps pending requests free of processed timestamps" do
    request = described_class.new(
      document:,
      requester:,
      title: "確認してください",
      approved_at: Time.current,
      cancelled_at: Time.current
    )

    expect(request).not_to be_valid
    expect(request.errors[:approved_at]).to include("must be blank")
    expect(request.errors[:cancelled_at]).to include("must be blank")
  end

  it "requires approved requests to have approval metadata only" do
    approved_request = described_class.new(
      document:,
      requester:,
      title: "確認しました",
      status: :approved,
      acted_by: internal_user,
      approved_at: Time.current,
      cancelled_at: nil
    )
    missing_metadata = described_class.new(document:, requester:, title: "確認しました", status: :approved)
    conflicting_metadata = described_class.new(
      document:,
      requester:,
      title: "確認しました",
      status: :approved,
      acted_by: internal_user,
      approved_at: Time.current,
      cancelled_at: Time.current
    )

    expect(approved_request).to be_valid
    expect(missing_metadata).not_to be_valid
    expect(missing_metadata.errors[:acted_by]).to include("must be present")
    expect(missing_metadata.errors[:approved_at]).to include("must be present")
    expect(conflicting_metadata).not_to be_valid
    expect(conflicting_metadata.errors[:cancelled_at]).to include("must be blank")
  end

  it "requires cancelled requests to have cancellation metadata only" do
    cancelled_request = described_class.new(
      document:,
      requester:,
      title: "取り下げます",
      status: :cancelled,
      acted_by: requester,
      cancelled_at: Time.current,
      approved_at: nil
    )
    missing_metadata = described_class.new(document:, requester:, title: "取り下げます", status: :cancelled)
    conflicting_metadata = described_class.new(
      document:,
      requester:,
      title: "取り下げます",
      status: :cancelled,
      acted_by: requester,
      cancelled_at: Time.current,
      approved_at: Time.current
    )

    expect(cancelled_request).to be_valid
    expect(missing_metadata).not_to be_valid
    expect(missing_metadata.errors[:acted_by]).to include("must be present")
    expect(missing_metadata.errors[:cancelled_at]).to include("must be present")
    expect(conflicting_metadata).not_to be_valid
    expect(conflicting_metadata.errors[:approved_at]).to include("must be blank")
  end

  it "clears cancellation metadata when approving a previously cancelled request" do
    request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "再確認してください",
      status: :cancelled,
      acted_by: requester,
      cancelled_at: 1.hour.ago,
      approved_at: nil
    )

    request.approve!(actor: internal_user)

    expect(request).to be_approved
    expect(request.acted_by).to eq(internal_user)
    expect(request.approved_at).to be_present
    expect(request.cancelled_at).to be_nil
  end

  it "clears approval metadata when cancelling a previously approved request" do
    request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "取り下げます",
      status: :approved,
      acted_by: internal_user,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )

    request.cancel!(actor: requester)

    expect(request).to be_cancelled
    expect(request.acted_by).to eq(requester)
    expect(request.cancelled_at).to be_present
    expect(request.approved_at).to be_nil
  end
end
