require "rails_helper"

RSpec.describe DocumentDeliveryLogBuilder do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:sender) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, visibility_policy: :restricted_external) }
  let(:attributes) do
    {
      to_addresses: "client@example.com",
      subject: "Please review",
      body: "Please review the portal document."
    }
  end

  before do
    create(:project_membership, project:, user: sender)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "builds a draft portal-link delivery log for readable documents" do
    log = described_class.new(sender:, project:, document:, attributes:).build

    expect(log).to be_valid
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.sender).to eq(sender)
    expect(log.delivery_type).to eq("portal_link")
    expect(log.status).to eq("draft")
  end

  it "creates a delivery log" do
    expect do
      described_class.new(sender:, project:, document:, attributes:).create!
    end.to change(DocumentDeliveryLog, :count).by(1)
  end

  it "rejects projects that the sender cannot view" do
    other_project = create(:project)

    expect do
      described_class.new(sender:, project: other_project, attributes:).build
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects documents that the sender cannot view" do
    document.update!(visibility_policy: :internal_only)

    expect do
      described_class.new(sender:, project:, document:, attributes:).build
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects documents outside the project" do
    other_project = create(:project)
    other_document = create(:document, project: other_project)

    expect do
      described_class.new(sender:, project:, document: other_document, attributes:).build
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
