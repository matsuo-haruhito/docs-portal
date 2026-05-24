require "rails_helper"

RSpec.describe "Company master admin boundaries", type: :request do
  let!(:company) { create(:company, domain: "tenant.example.com", name: "Tenant") }
  let!(:other_company) { create(:company, domain: "other.example.com", name: "Other") }
  let!(:manager) do
    create(
      :user,
      :external,
      :company_master_admin,
      company:,
      email_address: "manager@example.com"
    )
  end
  let!(:managed_user) do
    create(
      :user,
      :external,
      company:,
      email_address: "member@example.com"
    )
  end
  let!(:other_user) do
    create(
      :user,
      :external,
      company: other_company,
      email_address: "other@example.com"
    )
  end

  def denied_admin_paths
    {
      admin_projects_path => "案件",
      admin_documents_path => "文書",
      admin_document_permissions_path => "文書権限",
      admin_access_logs_path => "監査ログ",
      admin_access_requests_path => "アクセス申請"
    }
  end

  it "keeps allowed management pages scoped to the same company" do
    sign_in_as(manager)

    get admin_companies_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tenant")
    expect(response.body).not_to include("Other")

    get admin_users_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("manager@example.com")
    expect(response.body).to include("member@example.com")
    expect(response.body).not_to include("other@example.com")
  end

  it "forbids admin-only management surfaces for company_master_admin users" do
    sign_in_as(manager)

    denied_admin_paths.each do |path, label|
      get path

      expect(response).to have_http_status(:forbidden), "expected #{label} (#{path}) to stay forbidden"
    end
  end
end
