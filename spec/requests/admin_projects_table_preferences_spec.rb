require "rails_helper"

RSpec.describe "Admin projects table preferences", type: :request do
  let(:admin) { create(:user, :admin) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  def project_table
    parsed_html.at_css('[data-rails-table-preferences-table-key-value="admin_projects"]')
  end

  it "renders the admin_projects editor, filters, and stable project column keys when projects exist" do
    company = create(:company, name: "Example Corp", domain: "example.test")
    create(:project, code: "ALPHA", name: "Alpha Project", company:, description: "First project", active: true)
    create(:project, code: "OMEGA", name: "Omega Project", description: "Archived project", active: false)
    sign_in_as(admin)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(project_table).to be_present
    expect(project_column_keys).to contain_exactly("code", "name", "company", "description", "status", "actions")
    expect(parsed_html.at_css('.admin-filter-toolbar input[name="q"]')).to be_present
    expect(parsed_html.at_css('.admin-filter-toolbar select[name="active"]')).to be_present
    expect(parsed_html.at_css('.admin-filter-toolbar select[name="company_id"]')).to be_present
    expect(page_text).to include("ALPHA", "Example Corp", "未設定", "有効", "無効")
  end

  it "filters projects by keyword, active state, and company without changing the table contract" do
    company = create(:company, name: "Example Corp", domain: "example.test")
    other_company = create(:company, name: "Other Corp", domain: "other.test")
    create(:project, code: "ALPHA", name: "Alpha Portal", company:, description: "Git setup", active: true)
    create(:project, code: "BETA", name: "Beta Portal", company: other_company, description: "Archive", active: true)
    create(:project, code: "OMEGA", name: "Omega Archive", company:, description: "Git setup", active: false)
    sign_in_as(admin)

    get admin_projects_path, params: { q: "git", active: "true", company_id: company.id }

    expect(response).to have_http_status(:ok)
    expect(project_column_keys).to contain_exactly("code", "name", "company", "description", "status", "actions")
    expect(page_text).to include("ALPHA", "Alpha Portal")
    expect(page_text).not_to include("BETA", "OMEGA")
    expect(parsed_html.css(".admin-filter-chip").map { |node| node.text.squish }).to contain_exactly(
      "検索: git",
      "状態: 有効",
      "会社: Example Corp"
    )
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("1件")
  end

  it "can filter projects without a company" do
    create(:company, name: "Example Corp", domain: "example.test")
    create(:project, code: "NOCO", name: "No Company Project", company: nil, active: true)
    create(:project, code: "WITH", name: "With Company Project", company: Company.first, active: true)
    sign_in_as(admin)

    get admin_projects_path, params: { company_id: "none" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("NOCO", "未設定")
    expect(page_text).not_to include("WITH")
  end

  it "distinguishes a filtered empty result from the unregistered empty state" do
    create(:project, code: "ALPHA", name: "Alpha Project", active: true)
    sign_in_as(admin)

    get admin_projects_path, params: { q: "missing-project" }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".empty-state")).to be_present
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("0件")
    expect(parsed_html.css('a[href="/admin/projects"]').map { |link| link.text.squish }).to include("条件をクリア")
    expect(project_table).to be_nil
    expect(project_column_keys).to be_empty
  end

  it "keeps the unregistered empty state without rendering the preferences table" do
    sign_in_as(admin)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".empty-state")).to be_present
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("0件")
    expect(project_table).to be_nil
    expect(project_column_keys).to be_empty
  end
end
