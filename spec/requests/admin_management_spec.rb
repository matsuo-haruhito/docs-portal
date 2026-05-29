require "rails_helper"

RSpec.describe "Admin management", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def admin_nav_hrefs
    parsed_html.css("ul.nav-list a").map { |link| link["href"] }
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  describe "GET /admin" do
    it "redirects unauthenticated users to the login page" do
      get admin_root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "allows internal users" do
      sign_in_as(create(:user, :internal))

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("管理画面")
      expect(admin_nav_hrefs).to include(
        admin_root_path,
        admin_projects_path,
        admin_document_usage_reports_path
      )
    end

    it "shows company_master_admin users a scoped company and user landing" do
      company = create(:company, domain: "alpha.example.com", name: "Alpha")
      sign_in_as(create(:user, :external, :company_master_admin, company:))

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("会社・ユーザー管理")
      expect(page_text).to include("使える管理画面")
      expect(page_text).to include("internal admin へ戻す範囲")
      expect(page_text).to include("0 件のときもユーザー画面上部の新規登録から開始できます")
      expect(action_targets).to include(admin_companies_path, admin_users_path)
      expect(action_targets).not_to include(
        admin_projects_path,
        admin_project_memberships_path,
        admin_documents_path,
        admin_document_permissions_path,
        admin_access_logs_path,
        admin_document_usage_reports_path
      )
      expect(page_text).not_to include("モデル観測")
      expect(page_text).not_to include("アプリ設定診断")
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

      patch admin_company_path(created.public_id), params: {
        company: { domain: "beta.example.com", name: "Beta Updated", active: false }
      }

      expect(response).to redirect_to(admin_companies_path)
      expect(created.reload.name).to eq("Beta Updated")
      expect(created.active).to be(false)

      expect do
        delete admin_company_path(created.public_id)
      end.to change(Company, :count).by(-1)

      expect(response).to redirect_to(admin_companies_path)
    end

    it "uses public_id-based company action links and rejects numeric ids" do
      sign_in_as(internal_user)

      get admin_companies_path

      expect(response).to have_http_status(:ok)
      expect(action_targets).to include(edit_admin_company_path(company.public_id))
      expect(action_targets).to include(admin_company_path(company.public_id))
      expect(action_targets).not_to include(edit_admin_company_path(company.id))
      expect(action_targets).not_to include(admin_company_path(company.id))
      expect(admin_company_path(company)).to eq("/admin/companies/#{company.public_id}")
      expect(edit_admin_company_path(company)).to eq("/admin/companies/#{company.public_id}/edit")

      get edit_admin_company_path(company.public_id)
      expect(response).to have_http_status(:ok)

      get edit_admin_company_path(company.id)
      expect(response).to have_http_status(:not_found)

      patch admin_company_path(company.id), params: {
        company: { domain: company.domain, name: "Numeric Id Update", active: false }
      }

      expect(response).to have_http_status(:not_found)
      expect(company.reload.name).to eq("Alpha")

      delete admin_company_path(company.id)

      expect(response).to have_http_status(:not_found)
      expect(Company.exists?(company.id)).to be(true)
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
      expect(page_text).to include("Alpha")
      expect(page_text).not_to include("Omega")

      patch admin_company_path(company.public_id), params: {
        company: { domain: company.domain, name: "Alpha Updated", active: false }
      }

      expect(response).to redirect_to(admin_companies_path)
      expect(company.reload.name).to eq("Alpha Updated")

      patch admin_company_path(other_company.public_id), params: {
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
      expect(admin_project_path(project)).to eq("/admin/projects/PJ999")
      expect(edit_admin_project_path(project)).to eq("/admin/projects/PJ999/edit")

      get admin_projects_path
      expect(page_text).to include("Client Co")

      patch admin_project_path(project), params: {
        project: { code: "PJ999", name: "Portal Refresh Updated", description: "changed", company_id: "", active: false }
      }

      expect(response).to redirect_to(admin_projects_path)
      expect(project.reload.name).to eq("Portal Refresh Updated")
      expect(project.company).to be_nil
      expect(project.active).to be(false)

      get edit_admin_project_path(project.id)
      expect(response).to have_http_status(:not_found)
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_projects_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "company master user management" do
    let(:internal_user) { create(:user, :internal) }
    let!(:company) { create(:company, domain: "tenant.example.com", name: "Tenant") }
    let!(:other_company) { create(:company, domain: "other.example.com", name: "Other") }
    let!(:manager) { create(:user, :external, :company_master_admin, company:, email_address: "manager@example.com") }
    let!(:managed_user) { create(:user, :external, company:, email_address: "member@example.com") }
    let!(:other_user) { create(:user, :external, company: other_company, email_address: "other@example.com") }

    it "limits company_master_admin to users in the same company" do
      sign_in_as(manager)

      get admin_users_path
      expect(response).to have_http_status(:ok)
      expect(page_text).to include("member@example.com")
      expect(page_text).not_to include("other@example.com")
      expect(admin_nav_hrefs).to include(admin_companies_path, admin_users_path)
      expect(admin_nav_hrefs).not_to include(
        admin_root_path,
        admin_projects_path,
        admin_project_memberships_path,
        admin_documents_path,
        admin_document_permissions_path,
        admin_access_logs_path,
        admin_document_usage_reports_path
      )

      patch admin_user_path(managed_user.public_id), params: {
        user: { name: "Member Updated", email_address: managed_user.email_address, user_type: :internal, company_id: other_company.id, active: true }
      }

      expect(response).to redirect_to(admin_users_path)
      expect(managed_user.reload.name).to eq("Member Updated")
      expect(managed_user.user_type).to eq("external")
      expect(managed_user.company_id).to eq(company.id)

      get edit_admin_user_path(other_user.public_id)
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

    it "uses public_id-based user action links and rejects numeric ids" do
      sign_in_as(manager)

      get admin_users_path

      expect(response).to have_http_status(:ok)
      expect(action_targets).to include(edit_admin_user_path(managed_user.public_id))
      expect(action_targets).to include(admin_user_path(managed_user.public_id))
      expect(action_targets).not_to include(edit_admin_user_path(managed_user.id))
      expect(action_targets).not_to include(admin_user_path(managed_user.id))
      expect(admin_user_path(managed_user)).to eq("/admin/users/#{managed_user.public_id}")
      expect(edit_admin_user_path(managed_user)).to eq("/admin/users/#{managed_user.public_id}/edit")

      get edit_admin_user_path(managed_user.public_id)
      expect(response).to have_http_status(:ok)

      get edit_admin_user_path(managed_user.id)
      expect(response).to have_http_status(:not_found)

      patch admin_user_path(managed_user.id), params: {
        user: {
          name: "Numeric Id Update",
          email_address: managed_user.email_address,
          user_type: :external,
          company_id: company.id,
          active: true
        }
      }

      expect(response).to have_http_status(:not_found)
      expect(managed_user.reload.name).not_to eq("Numeric Id Update")
    end

    it "destroys same-company users via public_id and rejects numeric ids" do
      sign_in_as(manager)

      delete admin_user_path(managed_user.id)

      expect(response).to have_http_status(:not_found)
      expect(User.exists?(managed_user.id)).to be(true)

      expect do
        delete admin_user_path(managed_user.public_id)
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(admin_users_path)
    end

    it "keeps company_master_admin users out of unrelated admin surfaces" do
      guarded_paths = [
        admin_projects_path,
        admin_documents_path,
        admin_document_permissions_path,
        admin_access_logs_path,
        admin_document_usage_reports_path
      ]

      sign_in_as(internal_user)

      guarded_paths.each do |path|
        get path
        expect(response).to have_http_status(:ok)
      end

      sign_in_as(manager)

      guarded_paths.each do |path|
        get path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
