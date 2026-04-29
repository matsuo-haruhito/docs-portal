require "rails_helper"

RSpec.describe "Admin management", type: :request do
  describe "GET /admin" do
    it "redirects unauthenticated users to the login page" do
      get admin_root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows internal users" do
      sign_in_as(create(:user, :internal))

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("管理画面")
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_root_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "company master" do
    let(:internal_user) { create(:user, :internal) }
    let!(:company) { create(:company, code: "C001", name: "Alpha") }

    it "allows internal users to create, update, and destroy companies" do
      sign_in_as(internal_user)

      expect do
        post admin_companies_path, params: {
          company: { code: "C002", name: "Beta", active: true }
        }
      end.to change(Company, :count).by(1)

      created = Company.find_by!(code: "C002")
      expect(response).to redirect_to(admin_companies_path)
      expect(flash[:notice]).to eq("会社を登録しました。")

      patch admin_company_path(created), params: {
        company: { code: "C002", name: "Beta Updated", active: false }
      }

      expect(response).to redirect_to(admin_companies_path)
      expect(created.reload.name).to eq("Beta Updated")
      expect(created.active).to be(false)

      expect do
        delete admin_company_path(created)
      end.to change(Company, :count).by(-1)

      expect(response).to redirect_to(admin_companies_path)
    end

    it "forbids external users from company master access" do
      sign_in_as(create(:user, :external))

      get admin_companies_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "project master" do
    let(:internal_user) { create(:user, :internal) }

    it "allows internal users to manage projects" do
      sign_in_as(internal_user)

      expect do
        post admin_projects_path, params: {
          project: { code: "PJ999", name: "Portal Refresh", description: "desc", active: true }
        }
      end.to change(Project, :count).by(1)

      project = Project.find_by!(code: "PJ999")
      expect(response).to redirect_to(admin_projects_path)

      patch admin_project_path(project), params: {
        project: { code: "PJ999", name: "Portal Refresh Updated", description: "changed", active: false }
      }

      expect(response).to redirect_to(admin_projects_path)
      expect(project.reload.name).to eq("Portal Refresh Updated")
      expect(project.active).to be(false)
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_projects_path

      expect(response).to have_http_status(:forbidden)
    end
  end
end
