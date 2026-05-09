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
    let!(:company) { create(:company, domain: "alpha.example.com", name: "Alpha") }
    let!(:other_company) { create(:company, domain: "omega.example.com", name: "Omega") }

    it "allows internal users to create, update, and destroy companies" do
      sign_in_as(internal_user)

      expect do
        post admin_companies_path, params: {
          company: { domain: "beta.example.com", name: "Beta", active: true }
        }
      end.to change(Company, :count).by(1)

      created = Company.find_by!(domain: "beta.example.com")
      expect(response).to redirect_to(admin_companies_path)
      expect(flash[:notice]).to eq("会社を登録しました。")

      patch admin_company_path(created), params: {
        company: { domain: "beta.example.com", name: "Beta Updated", active: false }
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

    it "allows company_master_admin users to update only their own company" do
      manager = create(:user, :external, user_type: :company_master_admin, company:)
      sign_in_as(manager)

      get admin_companies_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alpha")
      expect(response.body).not_to include("Omega")

      patch admin_company_path(company), params: {
        company: { domain: company.domain, name: "Alpha Updated", active: false }
      }

      expect(response).to redirect_to(admin_companies_path)
      expect(company.reload.name).to eq("Alpha Updated")

      patch admin_company_path(other_company), params: {
        company: { domain: other_company.domain, name: "Omega Updated", active: false }
      }

      expect(response).to have_http_status(:not_found)

      post admin_companies_path, params: {
        company: { domain: "forbidden.example.com", name: "Forbidden", active: true }
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "project master" do
    let(:internal_user) { create(:user, :internal) }
    let!(:company) { create(:company, domain: "client.example.com", name: "Client Co") }

    it "allows internal users to manage projects with optional companies" do
      sign_in_as(internal_user)

      expect do
        post admin_projects_path, params: {
          project: { code: "PJ999", name: "Portal Refresh", description: "desc", company_id: company.id, active: true }
        }
      end.to change(Project, :count).by(1)

      project = Project.find_by!(code: "PJ999")
      expect(response).to redirect_to(admin_projects_path)
      expect(project.company).to eq(company)

      get admin_projects_path
      expect(response.body).to include("Client Co")

      patch admin_project_path(project), params: {
        project: { code: "PJ999", name: "Portal Refresh Updated", description: "changed", company_id: "", active: false }
      }

      expect(response).to redirect_to(admin_projects_path)
      expect(project.reload.name).to eq("Portal Refresh Updated")
      expect(project.company).to be_nil
      expect(project.active).to be(false)
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_projects_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "company master user management" do
    let!(:company) { create(:company, domain: "tenant.example.com", name: "Tenant") }
    let!(:other_company) { create(:company, domain: "other.example.com", name: "Other") }
    let!(:manager) { create(:user, :external, user_type: :company_master_admin, company:, email_address: "manager@example.com") }
    let!(:managed_user) { create(:user, :external, company:, email_address: "member@example.com") }
    let!(:other_user) { create(:user, :external, company: other_company, email_address: "other@example.com") }

    it "limits company_master_admin to users in the same company" do
      sign_in_as(manager)

      get admin_users_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("member@example.com")
      expect(response.body).not_to include("other@example.com")

      patch admin_user_path(managed_user), params: {
        user: { name: "Member Updated", email_address: managed_user.email_address, user_type: :internal, company_id: other_company.id, active: true }
      }

      expect(response).to redirect_to(admin_users_path)
      expect(managed_user.reload.name).to eq("Member Updated")
      expect(managed_user.user_type).to eq("external")
      expect(managed_user.company_id).to eq(company.id)

      get edit_admin_user_path(other_user)
      expect(response).to have_http_status(:not_found)

      post admin_users_path, params: {
        user: {
          name: "New Member",
          email_address: "new-member@example.com",
          user_type: :internal,
          company_id: other_company.id,
          active: true,
          password: "password123!",
          password_confirmation: "password123!"
        }
      }

      created = User.find_by!(email_address: "new-member@example.com")
      expect(response).to redirect_to(admin_users_path)
      expect(created.company_id).to eq(company.id)
      expect(created.user_type).to eq("external")

      get admin_projects_path
      expect(response).to have_http_status(:forbidden)
    end
  end
end
