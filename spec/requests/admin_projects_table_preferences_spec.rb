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
    parsed_html.css('[data-rails-table-preferences-column-key]').map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  it "renders the admin_projects editor and stable project column keys when projects exist" do
    company = create(:company, name: "Example Corp", domain: "example.test")
    create(:project, code: "ALPHA", name: "Alpha Project", company:, description: "First project", active: true)
    create(:project, code: "OMEGA", name: "Omega Project", description: "Archived project", active: false)
    sign_in_as(admin)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件一覧の表示設定")
    expect(response.body).to include("admin_projects")
    expect(project_column_keys).to contain_exactly("code", "name", "company", "description", "status", "actions")
    expect(page_text).to include("案件を探す")
    expect(page_text).to include("キーワード")
    expect(page_text).to include("状態")
    expect(page_text).to include("企業")
    expect(page_text).to include("ALPHA")
    expect(page_text).to include("Example Corp")
    expect(page_text).to include("未設定")
    expect(page_text).to include("有効")
    expect(page_text).to include("無効")
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
    expect(page_text).to include("ALPHA")
    expect(page_text).to include("Alpha Portal")
    expect(page_text).not_to include("BETA")
    expect(page_text).not_to include("OMEGA")
  end

  it "can filter projects without a company" do
    create(:company, name: "Example Corp", domain: "example.test")
    create(:project, code: "NOCO", name: "No Company Project", company: nil, active: true)
    create(:project, code: "WITH", name: "With Company Project", company: Company.first, active: true)
    sign_in_as(admin)

    get admin_projects_path, params: { company_id: "none" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("NOCO")
    expect(page_text).to include("未設定")
    expect(page_text).not_to include("WITH")
  end

  it "distinguishes a filtered empty result from the unregistered empty state" do
    create(:project, code: "ALPHA", name: "Alpha Project", active: true)
    sign_in_as(admin)

    get admin_projects_path, params: { q: "missing-project" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する案件はありません。")
    expect(page_text).to include("キーワード、状態、企業の条件を変更するか、条件をクリアしてください。")
    expect(page_text).not_to include("まだ案件は登録されていません。")
    expect(response.body).not_to include("案件一覧の表示設定")
    expect(project_column_keys).to be_empty
  end

  it "keeps the unregistered empty state without rendering the preferences table" do
    sign_in_as(admin)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ案件は登録されていません。")
    expect(response.body).not_to include("案件一覧の表示設定")
    expect(project_column_keys).to be_empty
  end
end
