require "rails_helper"

RSpec.describe "Admin master maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company, domain: "client-a.example.com", name: "Client A") }
  let(:other_company) { create(:company, domain: "other.example.com", name: "Other Company") }

  def with_read_only_maintenance(value)
    previous = ENV.fetch(Admin::BaseController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[Admin::BaseController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(Admin::BaseController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::BaseController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  def maintenance_message
    "メンテナンス中のため会社・ユーザー・案件所属の変更操作は停止しています"
  end

  it "does not create, update, or destroy companies during read-only maintenance" do
    target_company = create(:company, domain: "target.example.com", name: "Target Company", active: true)
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        post admin_companies_path, params: {
          company: { domain: "new-company.example.com", name: "New Company", active: "1" }
        }
      end
    end.not_to change(Company, :count)

    expect(response).to redirect_to(admin_companies_path)
    expect(flash[:alert]).to include(maintenance_message)

    with_read_only_maintenance("true") do
      patch admin_company_path(target_company.public_id), params: {
        return_to: admin_companies_path(q: "target", active: "true"),
        company: { domain: "target.example.com", name: "Updated Company", active: "0" }
      }
    end

    expect(response).to redirect_to(admin_companies_path(q: "target", active: "true"))
    expect(flash[:alert]).to include(maintenance_message)
    expect(target_company.reload.name).to eq("Target Company")
    expect(target_company).to be_active

    expect do
      with_read_only_maintenance("1") do
        delete admin_company_path(target_company.public_id)
      end
    end.not_to change(Company, :count)

    expect(response).to redirect_to(admin_companies_path)
    expect(Company.exists?(target_company.id)).to be(true)
  end

  it "does not create, update, or destroy users during read-only maintenance" do
    target_user = create(:user, :external, company:, name: "Target User", email_address: "target@example.com", active: true)
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        post admin_users_path, params: {
          user: {
            name: "New User",
            email_address: "new-user@example.com",
            user_type: "external",
            company_id: company.id,
            active: "1",
            password: "password123!",
            password_confirmation: "password123!"
          }
        }
      end
    end.not_to change(User, :count)

    expect(response).to redirect_to(admin_users_path)
    expect(flash[:alert]).to include(maintenance_message)

    with_read_only_maintenance("true") do
      patch admin_user_path(target_user.public_id), params: {
        return_to: admin_users_path(q: "target", active: "true"),
        user: {
          name: "Updated User",
          email_address: target_user.email_address,
          user_type: "external",
          company_id: company.id,
          active: "0"
        }
      }
    end

    expect(response).to redirect_to(admin_users_path(q: "target", active: "true"))
    expect(flash[:alert]).to include(maintenance_message)
    expect(target_user.reload.name).to eq("Target User")
    expect(target_user).to be_active

    expect do
      with_read_only_maintenance("1") do
        delete admin_user_path(target_user.public_id)
      end
    end.not_to change(User, :count)

    expect(response).to redirect_to(admin_users_path)
    expect(User.exists?(target_user.id)).to be(true)
  end

  it "does not create, update, or destroy project memberships during read-only maintenance" do
    project = create(:project, code: "MAINT-001", name: "Maintenance Project")
    user = create(:user, :external, company:, email_address: "member@example.com")
    membership = create(:project_membership, project:, user:, role: :viewer)
    other_project = create(:project, code: "MAINT-002", name: "Other Maintenance Project")
    other_user = create(:user, :external, company:, email_address: "other-member@example.com")
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        post admin_project_memberships_path, params: {
          project_membership: { project_id: other_project.id, user_id: other_user.id, role: "viewer" }
        }
      end
    end.not_to change(ProjectMembership, :count)

    expect(response).to redirect_to(admin_project_memberships_path)
    expect(flash[:alert]).to include(maintenance_message)

    with_read_only_maintenance("true") do
      patch admin_project_membership_path(membership.public_id), params: {
        project_membership: { project_id: project.id, user_id: user.id, role: "owner" }
      }
    end

    expect(response).to redirect_to(admin_project_memberships_path)
    expect(flash[:alert]).to include(maintenance_message)
    expect(membership.reload.role).to eq("viewer")

    expect do
      with_read_only_maintenance("1") do
        delete admin_project_membership_path(membership.public_id)
      end
    end.not_to change(ProjectMembership, :count)

    expect(response).to redirect_to(admin_project_memberships_path)
    expect(ProjectMembership.exists?(membership.id)).to be(true)
  end

  it "keeps company master admin company and user lists readable during read-only maintenance" do
    company_admin = create(:user, :company_master_admin, company:, name: "Company Admin", email_address: "company-admin@example.com")
    scoped_user = create(:user, :external, company:, name: "Scoped User", email_address: "scoped@example.com")
    other_user = create(:user, :external, company: other_company, name: "Other User", email_address: "other@example.com")
    sign_in_as(company_admin)

    with_read_only_maintenance("1") do
      get admin_companies_path, params: { q: "Client", active: "true" }
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(company.name)
    expect(response.body).not_to include(other_company.name)

    with_read_only_maintenance("1") do
      get admin_users_path, params: { q: "Scoped", active: "true" }
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(scoped_user.email_address)
    expect(response.body).not_to include(other_user.email_address)

    with_read_only_maintenance("1") do
      get company_search_admin_users_path, params: { q: company.domain }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("options").map { _1.fetch("value") }).to eq([company.id])

    with_read_only_maintenance("1") do
      get selected_company_admin_users_path, params: { id: company.id }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("option", "value")).to eq(company.id)
  end

  it "keeps project membership index and lookup endpoints readable during read-only maintenance" do
    project = create(:project, code: "LOOKUP-001", name: "Lookup Project")
    user = create(:user, :external, company:, name: "Lookup User", email_address: "lookup@example.com")
    membership = create(:project_membership, project:, user:, role: :viewer)
    sign_in_as(admin_user)

    with_read_only_maintenance("1") do
      get admin_project_memberships_path
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project.name, user.email_address)

    with_read_only_maintenance("1") do
      get project_search_admin_project_memberships_path, params: { q: "LOOKUP" }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("options").first.fetch("value")).to eq(project.id)

    with_read_only_maintenance("1") do
      get selected_project_admin_project_memberships_path, params: { id: project.id }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("option", "value")).to eq(project.id)

    with_read_only_maintenance("1") do
      get user_search_admin_project_memberships_path, params: { q: "lookup" }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("options").first.fetch("value")).to eq(user.id)

    with_read_only_maintenance("1") do
      get selected_user_admin_project_memberships_path, params: { id: user.id }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("option", "value")).to eq(user.id)
    expect(membership.reload.role).to eq("viewer")
  end

  it "keeps representative create and update flows working when read-only maintenance is disabled" do
    project = create(:project)
    user = create(:user, :external, company:)
    membership = create(:project_membership, project:, user:, role: :viewer)
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("0") do
        post admin_companies_path, params: {
          company: { domain: "enabled.example.com", name: "Enabled Company", active: "1" }
        }
      end
    end.to change(Company, :count).by(1)

    expect(response).to redirect_to(admin_companies_path)

    expect do
      with_read_only_maintenance("0") do
        post admin_users_path, params: {
          user: {
            name: "Enabled User",
            email_address: "enabled-user@example.com",
            user_type: "external",
            company_id: company.id,
            active: "1",
            password: "password123!",
            password_confirmation: "password123!"
          }
        }
      end
    end.to change(User, :count).by(1)

    expect(response).to redirect_to(admin_users_path)

    with_read_only_maintenance("0") do
      patch admin_project_membership_path(membership.public_id), params: {
        project_membership: { project_id: project.id, user_id: user.id, role: "owner" }
      }
    end

    expect(response).to redirect_to(admin_project_memberships_path)
    expect(membership.reload.role).to eq("owner")
  end
end
