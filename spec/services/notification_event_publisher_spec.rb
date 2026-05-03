require "rails_helper"

RSpec.describe NotificationEventPublisher do
  let(:actor) { create(:user, :internal) }
  let(:project) { create(:project, code: "NOTICE", name: "Notice Project") }
  let(:document) { create(:document, project:, title: "通知対象文書", slug: "notice-doc", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  it "creates a document update event and unread receipts for viewable project users" do
    internal_user = create(:user, :internal)
    external_company_user = create(:user, :external)
    external_hidden_user = create(:user, :external)
    create(:project_membership, project:, user: external_company_user)
    create(:project_membership, project:, user: external_hidden_user)
    create(:document_permission, document:, company: external_company_user.company, access_level: :view)

    event = described_class.new(actor_user: actor).publish_document_updated!(document_version: version, body: "updated")

    expect(event).to be_document_updated
    expect(event.project).to eq(project)
    expect(event.document).to eq(document)
    expect(event.document_version).to eq(version)
    expect(event.actor_user).to eq(actor)
    expect(event.title).to include("通知対象文書")
    expect(event.body).to eq("updated")
    expect(event.notification_receipts.map(&:user)).to contain_exactly(actor, internal_user, external_company_user)
    expect(event.notification_receipts).to all(have_attributes(read_at: nil))
  end
end
