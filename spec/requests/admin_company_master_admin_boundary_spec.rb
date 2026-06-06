require "rails_helper"

RSpec.describe "Company master admin boundary", type: :request do
  let(:company) { create(:company, domain: "owned.example.com", name: "Owned Company") }
  let(:other_company) { create(:company, domain: "other.example.com", name: "Other Company") }
  let(:company_master_admin) { create(:user, :company_master_admin, company:, name: "Company Admin") }
  let!(:same_company_user) { create(:user, :external, company:, name: "Owned User", email_address: "owned-user@example.com") }
  let!(:other_company_user) { create(:user, :external, company: other_company, name: "Other User", email_address: "other-user@example.com") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def link_hrefs
    parsed_html.css("a").map { |link| link["href"] }
  end

  before do
    sign_in_as(company_master_admin)
  end

  it "shows only the company and user admin surfaces on the admin landing and nav" do
    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("会社・ユーザー管理")
    expect(page_text).to include("使える管理画面")
    expect(page_text).to include("internal admin へ戻す範囲")
    expect(link_hrefs).to include(admin_companies_path, admin_users_path)
    expect(link_hrefs).not_to include(
      admin_projects_path,
      admin_project_memberships_path,
      admin_documents_path,
      admin_document_permissions_path,
      admin_access_logs_path,
      admin_document_usage_reports_path
    )
  end

  it "allows the current company and same-company users while hiding other companies" do
    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Owned Company")
    expect(page_text).to include("owned.example.com")
    expect(page_text).not_to include("Other Company")
    expect(page_text).not_to include("other.example.com")

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Owned User")
    expect(page_text).to include("owned-user@example.com")
    expect(page_text).not_to include("Other User")
    expect(page_text).not_to include("other-user@example.com")
  end

  it "keeps representative internal-admin surfaces forbidden for company master admins" do
    forbidden_surfaces = {
      "projects" => admin_projects_path,
      "project memberships" => admin_project_memberships_path,
      "documents" => admin_documents_path,
      "document permissions" => admin_document_permissions_path,
      "access logs" => admin_access_logs_path,
      "usage reports" => admin_document_usage_reports_path
    }

    aggregate_failures "forbidden admin surfaces" do
      forbidden_surfaces.each do |label, path|
        get path
        expect(response).to have_http_status(:forbidden), "expected #{label} to be forbidden"
      end
    end
  end
end
