require "rails_helper"
require "securerandom"

RSpec.describe "Project access", type: :request do
  let(:external_user) { create(:user, :external) }
  let(:member_project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Member Project") }
  let(:other_project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Other Project") }
  let!(:member_document) { create(:document, project: member_project, title: "Member Doc", slug: "member-doc") }

  before do
    create(:project_membership, project: member_project, user: external_user)
  end

  it "allows external users to access only their member project show page" do
    sign_in_as(external_user)

    get project_path(member_project)
    expect(response).to have_http_status(:ok)

    get project_path(other_project)
    expect(response).to have_http_status(:forbidden)
  end

  it "forbids external users from accessing documents index for non-member projects" do
    sign_in_as(external_user)

    get project_documents_path(other_project)

    expect(response).to have_http_status(:forbidden)
  end

  it "allows external users to access documents index for member projects" do
    sign_in_as(external_user)

    get project_documents_path(member_project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Member Doc")
  end
end
