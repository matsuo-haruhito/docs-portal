require "rails_helper"

RSpec.describe "Error pages", type: :request do
  let(:external_user) { create(:user, :external, company: create(:company)) }
  let(:member_project) { create(:project, code: "ERRMEM", name: "Member Project") }
  let(:other_project) { create(:project, code: "ERROTH", name: "Other Project") }

  before do
    create(:project_membership, project: member_project, user: external_user)
  end

  it "renders friendly forbidden, not found, and bad request pages" do
    sign_in_as(external_user)

    get project_path(other_project)
    expect(response).to have_http_status(:forbidden)
    expect(response.body).to include("アクセスできません")
    expect(response.body).to include("権限がありません")

    get project_path("missing-project")
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("見つかりません")

    post project_document_zip_path(member_project)
    expect(response).to have_http_status(:bad_request)
    expect(response.body).to include("リクエストを処理できません")
  end
end
