require "rails_helper"

RSpec.describe "Admin model browsers", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company_master_admin) { create(:user, :company_master_admin) }

  it "shows the model browser index to admins" do
    create(:project)
    create(:document)

    sign_in_as(admin_user)
    get admin_model_browser_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("モデルブラウザ")
    expect(response.body).to include("案件")
    expect(response.body).to include("文書")
  end

  it "shows a model-specific browser page to admins" do
    project = create(:project, code: "BROWSE01", name: "Browse Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最近のデータ")
    expect(response.body).to include(project.code)
    expect(response.body).to include(project.name)
  end

  it "localizes summary field labels and boolean values on model pages" do
    create(:user, :internal, name: "Active User", email_address: "active@example.com", active: true)
    create(:user, :internal, name: "Inactive User", email_address: "inactive@example.com", active: false)

    sign_in_as(admin_user)
    get admin_model_browser_model_path("users")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("公開ID")
    expect(response.body).to include("メールアドレス")
    expect(response.body).to include("有効")
    expect(response.body).to include("更新日時")
    expect(response.body).to include("はい")
    expect(response.body).to include("いいえ")
    expect(response.body).to include("inactive@example.com")
  end

  it "forbids company master admins from the model browser" do
    sign_in_as(company_master_admin)
    get admin_model_browser_path

    expect(response).to have_http_status(:forbidden)
  end
end
