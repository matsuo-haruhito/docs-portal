require "rails_helper"

RSpec.describe "Admin model browsers", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company_master_admin) { create(:user, :company_master_admin) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "redirects unauthenticated users to the login page" do
    get admin_model_browser_path

    expect(response).to redirect_to(new_session_path)
  end

  it "shows the model browser index to admins grouped by catalog area" do
    create(:project)
    create(:document)

    sign_in_as(admin_user)
    get admin_model_browser_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("モデルブラウザ")
    expect(response.body).to include("基本マスタ")
    expect(response.body).to include("文書・権限")
    expect(response.body).to include("import / sync")
    expect(response.body).to include("外部連携")
    expect(response.body).to include("運用")
    expect(response.body).to include("案件")
    expect(response.body).to include("文書")
    expect(response.body).to include(admin_model_browser_model_path("projects"))
    expect(response.body).to include(admin_projects_path)
  end

  it "keeps every catalog entry in a known group without changing dashboard ordering" do
    entries = Admin::ModelBrowserCatalog.entries
    grouped_entries = Admin::ModelBrowserCatalog.grouped_entries(entries)

    expect(grouped_entries.map(&:first)).to eq(%i[basic_master document_permission import_sync external_integration operations])
    expect(entries.first(8).map(&:key)).to eq(%w[companies users projects project_memberships documents document_versions document_files document_permissions])
    expect(entries.map(&:group)).to all(satisfy { Admin::ModelBrowserCatalog::GROUP_LABELS.key?(_1) })
  end

  it "shows a model-specific browser page to admins" do
    project = create(:project, code: "BROWSE01", name: "Browse Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("件数")
    expect(response.body).to include("最終更新")
    expect(response.body).to include("代表フィールド検索")
    expect(response.body).to include("最近のデータ")
    expect(response.body).to include(project.code)
    expect(response.body).to include(project.name)
  end

  it "filters model pages by whitelisted text summary fields" do
    matching_project = create(:project, code: "SEARCH1674", name: "Needle Project")
    other_project = create(:project, code: "OTHER1674", name: "Other Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects", q: "Needle")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("検索語: Needle / 表示上限: 20件")
    expect(response.body).to include("検索対象:")
    expect(response.body).to include("コード")
    expect(response.body).to include(matching_project.code)
    expect(response.body).to include(matching_project.name)
    expect(response.body).not_to include(other_project.code)
    expect(response.body).not_to include(other_project.name)
  end

  it "matches numeric queries against id without adding write actions" do
    matching_project = create(:project, code: "IDMATCH1674", name: "ID Match Project")
    other_project = create(:project, code: "IDOTHER1674", name: "ID Other Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects", q: matching_project.id.to_s)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_project.code)
    expect(response.body).not_to include(other_project.code)
    expect(response.body).not_to include("削除")
  end

  it "shows an empty state for searches with no matching records" do
    project = create(:project, code: "MISS1674", name: "Miss Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects", q: "NO_MATCH_1674")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("該当するデータはありません")
    expect(response.body).not_to include(project.code)
  end

  it "handles overlong symbol queries without raising an error" do
    create(:project, code: "SYMBOL1674", name: "Symbol Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects", q: "!'" * 120)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("該当するデータはありません")
  end

  it "redirects unauthenticated users from model-specific browser pages" do
    get admin_model_browser_model_path("companies")

    expect(response).to redirect_to(new_session_path)
  end

  it "bounds recent model rows to 20 and orders updated records by updated_at then id descending" do
    admin_user.company.update!(updated_at: 2.years.ago)
    timestamp = Time.zone.local(2026, 5, 1, 12, 0, 0)
    companies = 21.times.map do |index|
      create(:company, name: format("Browser Company %02d", index), updated_at: timestamp)
    end

    sign_in_as(admin_user)
    get admin_model_browser_model_path("companies")

    expect(response).to have_http_status(:ok)

    row_texts = parsed_html.css("tbody tr").map { _1.text.squish }

    expect(row_texts.size).to eq(20)
    expect(row_texts.first).to include("Browser Company 20")
    expect(row_texts.second).to include("Browser Company 19")
    expect(row_texts.any? { _1.include?(companies.first.name) }).to be(false)
  end

  it "renders a not found response for an invalid model key" do
    sign_in_as(admin_user)

    get admin_model_browser_model_path("missing_model")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("見つかりません")
  end

  it "localizes summary field labels and boolean values on model pages" do
    create(:user, :internal, name: "Active User", email_address: "active@example.com", active: true)
    create(:user, :internal, name: "Inactive User", email_address: "inactive@example.com", active: false)

    sign_in_as(admin_user)
    get admin_model_browser_model_path("users")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("公開ID")
    expect(response.body).to include("メールアドレス")
    expect(response.body).to include("有効")
    expect(response.body).to include("更新日時")
    expect(response.body).to include("はい")
    expect(response.body).to include("いいえ")
    expect(response.body).to include("inactive@example.com")
  end

  it "forbids company master admins from the model browser" do
    sign_in_as(company_master_admin)
    get admin_model_browser_path

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids company master admins from model-specific browser pages" do
    sign_in_as(company_master_admin)
    get admin_model_browser_model_path("companies")

    expect(response).to have_http_status(:forbidden)
  end
end
