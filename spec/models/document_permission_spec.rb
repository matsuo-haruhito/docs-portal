require "rails_helper"

RSpec.describe DocumentPermission, type: :model do
  it "allows a company-scoped permission" do
    permission = build(:document_permission, company: create(:company), user: nil)

    expect(permission).to be_valid
  end

  it "allows a user-scoped permission" do
    permission = build(:document_permission, company: nil, user: create(:user))

    expect(permission).to be_valid
  end

  it "requires either company or user" do
    permission = build(:document_permission, company: nil, user: nil)

    expect(permission).not_to be_valid
    expect(permission.errors[:base]).to include("company_id or user_id is required")
  end

  it "does not allow both company and user to be set" do
    permission = build(:document_permission, company: create(:company), user: create(:user))

    expect(permission).not_to be_valid
    expect(permission.errors[:base]).to include("company_id and user_id cannot both be set")
  end

  it "does not allow duplicate company-scoped permissions for the same document" do
    existing = create(:document_permission)
    duplicate = build(:document_permission, document: existing.document, company: existing.company, user: nil)

    expect(duplicate).not_to be_valid
  end

  it "does not allow duplicate user-scoped permissions for the same document" do
    document = create(:document)
    user = create(:user)
    create(:document_permission, document:, company: nil, user:)

    duplicate = build(:document_permission, document:, company: nil, user:)

    expect(duplicate).not_to be_valid
  end
end
