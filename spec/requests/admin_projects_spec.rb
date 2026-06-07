require "rails_helper"

RSpec.describe "Admin projects", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_names
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='name']").map { |cell| cell.text.squish }
  end

  it "filters projects by keyword across code, name, and description" do
    create(:project, code: "NEEDLE-001", name: "Code Match", description: "Plain text")
    create(:project, code: "NAME-001", name: "Needle Name", description: "Plain text")
    create(:project, code: "DESC-001", name: "Description Match", description: "contains needle text")
    create(:project, code: "OTHER-001", name: "Other Project", description: "Plain text")

    sign_in_as(admin_user)

    get admin_projects_path(q: "needle")

    expect(response).to have_http_status(:ok)
    expect(project_names).to contain_exactly("Code Match", "Needle Name", "Description Match")
    expect(page_text).to include("適用中:")
    expect(page_text).to include("検索: needle")
    expect(page_text).to include("検索結果: 3件")
  end

  it "combines active and company filters" do
    company = create(:company, name: "Filter Company", domain: "filter.example.com")
    other_company = create(:company, name: "Other Company", domain: "other.example.com")
    create(:project, code: "ACTIVE", name: "Active Same Company", active: true, company:)
    create(:project, code: "INACTIVE", name: "Inactive Same Company", active: false, company:)
    create(:project, code: "OTHERCO", name: "Inactive Other Company", active: false, company: other_company)
    create(:project, code: "UNSET", name: "Inactive Unset Company", active: false, company: nil)

    sign_in_as(admin_user)

    get admin_projects_path(active: "false", company_id: company.id.to_s)

    expect(response).to have_http_status(:ok)
    expect(project_names).to eq(["Inactive Same Company"])
    expect(page_text).to include("状態: 無効")
    expect(page_text).to include("企業: Filter Company")
    expect(page_text).to include("検索結果: 1件")
    expect(page_text).to include("表示設定は列の表示・幅を調整し、絞り込みは一覧に出す案件を切り替えます。")
  end

  it "filters projects without a company separately from company projects" do
    company = create(:company, name: "Assigned Company", domain: "assigned.example.com")
    create(:project, code: "UNSET", name: "Unset Company Project", company: nil)
    create(:project, code: "ASSIGNED", name: "Assigned Company Project", company:)

    sign_in_as(admin_user)

    get admin_projects_path(company_id: "none")

    expect(response).to have_http_status(:ok)
    expect(project_names).to eq(["Unset Company Project"])
    expect(page_text).to include("未設定")
    expect(page_text).to include("企業: 企業未設定")
  end

  it "ignores unsupported filter values without raising errors" do
    create(:project, code: "ACTIVE", name: "Active Project", active: true)
    create(:project, code: "INACTIVE", name: "Inactive Project", active: false)

    sign_in_as(admin_user)

    get admin_projects_path(active: "archived", company_id: "not-a-company")

    expect(response).to have_http_status(:ok)
    expect(project_names).to contain_exactly("Active Project", "Inactive Project")
  end

  it "separates no projects from filtered empty results" do
    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ案件は登録されていません。")
    expect(page_text).not_to include("検索条件に一致する案件はありません。")

    create(:project, code: "EXISTING", name: "Existing Project")

    get admin_projects_path(q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致する案件はありません。")
    expect(page_text).not_to include("まだ案件は登録されていません。")
  end
end
