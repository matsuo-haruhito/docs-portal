require "rails_helper"

RSpec.describe "Admin API specifications", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows the API specification page from the admin menu" do
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("API仕様")
    expect(response.body).to include("docs-src/api-specification.md")
  end
end
