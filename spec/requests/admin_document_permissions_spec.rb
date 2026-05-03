require "rails_helper"

RSpec.describe "Admin document permissions", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows document permission overview" do
    document = create(:document, title: "Permission Target", visibility_policy: :restricted_external)
    company = create(:company, name: "Customer Company")
    external_user = create(:user, :external, email_address: "external@example.com")
    create(:document_permission, document:, company:, access_level: :view)
    create(:document_permission, document:, user: external_user, access_level: :download)

    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書別の権限概要")
    expect(response.body).to include("Permission Target")
    expect(response.body).to include("restricted_external")
    expect(response.body).to include("Customer Company")
    expect(response.body).to include("external@example.com")
  end
end
