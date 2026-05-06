require "rails_helper"

RSpec.describe DocumentApprovalRequest, type: :model do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
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
end
