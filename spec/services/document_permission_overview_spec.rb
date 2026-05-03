require "rails_helper"

RSpec.describe DocumentPermissionOverview do
  it "summarizes company and user permissions per document" do
    document = create(:document, title: "Permission Target")
    company_permission = create(:document_permission, document:, company: create(:company), access_level: :view)
    user_permission = create(:document_permission, document:, user: create(:user, :external), access_level: :download)

    rows = described_class.new(Document.where(id: document.id)).rows

    expect(rows.size).to eq(1)
    row = rows.first
    expect(row.document).to eq(document)
    expect(row.company_permissions).to eq([company_permission])
    expect(row.user_permissions).to eq([user_permission])
    expect(row.view_allowed_count).to eq(1)
    expect(row.download_allowed_count).to eq(1)
  end
end
