require "rails_helper"

RSpec.describe "Admin project templates", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "TPLADM", name: "Template Admin") }

  it "shows the standard template preview on project edit" do
    sign_in_as(admin_user)

    get edit_admin_project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("標準文書テンプレート")
    expect(response.body).to include("作成予定")
    expect(response.body).to include("要件定義 README")
  end

  it "applies the standard project template from admin" do
    sign_in_as(admin_user)

    expect do
      post apply_template_admin_project_path(project)
    end.to change(project.documents, :count).by(ProjectDocumentTemplate.load("standard_project").documents.size)

    expect(response).to redirect_to(edit_admin_project_path(project))
    expect(flash[:notice]).to include("標準テンプレートを適用しました。")
    expect(project.documents.find_by!(title: "業務フロー").latest_version.version_label).to eq("template")
  end

  it "skips existing template documents on repeated apply" do
    sign_in_as(admin_user)

    post apply_template_admin_project_path(project)
    expect(response).to redirect_to(edit_admin_project_path(project))

    expect do
      post apply_template_admin_project_path(project)
    end.not_to change(project.documents, :count)

    expect(response).to redirect_to(edit_admin_project_path(project))
    expect(flash[:notice]).to include("スキップ")
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get edit_admin_project_path(project)
    expect(response).to have_http_status(:forbidden)

    post apply_template_admin_project_path(project)
    expect(response).to have_http_status(:forbidden)
  end
end
