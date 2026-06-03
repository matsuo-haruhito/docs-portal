require "rails_helper"

RSpec.describe "Admin model browsers", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company_master_admin) { create(:user, :company_master_admin) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def model_browser_card_links
    parsed_html.css(".model-browser-group .metric-card h3 a")
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

  it "filters the model browser index by catalog label and keeps grouped cards" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "文書" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件: 文書")
    expect(response.body).to include("文書・権限")

    card_labels = model_browser_card_links.map { _1.text.squish }
    card_hrefs = model_browser_card_links.map { _1["href"] }

    expect(card_labels).to include("文書")
    expect(card_hrefs).to include(admin_model_browser_model_path("documents"))
    expect(card_hrefs).not_to include(admin_model_browser_model_path("companies"))
  end

  it "filters the model browser index by key while normalizing spaces and case" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "  DOCUMENT_FILES  " }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件: DOCUMENT_FILES")

    card_labels = model_browser_card_links.map { _1.text.squish }
    card_hrefs = model_browser_card_links.map { _1["href"] }

    expect(card_labels).to eq(["文書ファイル"])
    expect(card_hrefs).to eq([admin_model_browser_model_path("document_files")])
  end

  it "filters the model browser index by description and group label" do
    sign_in_as(admin_user)

    get admin_model_browser_path, params: { q: "公開単位" }
    expect(response).to have_http_status(:ok)
    expect(model_browser_card_links.map { _1["href"] }).to include(admin_model_browser_model_path("projects"))

    get admin_model_browser_path, params: { q: "import / sync" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("import / sync")
    expect(model_browser_card_links.map { _1["href"] }).to include(admin_model_browser_model_path("git_import_sources"))
  end

  it "shows a search empty state on the model browser index" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "missing catalog entry" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件に一致するモデルはありません。")
    expect(response.body).to include("モデル名、key、説明、group の表記を変えて再検索してください。")
    expect(model_browser_card_links).to be_empty
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
    expect(response.body).to include("最近のデータ")
    expect(response.body).to include("最新の代表データを最大20件まで表示します。この画面では編集や削除はできません。")
    expect(response.body).to include("既存画面で詳しく確認")
    expect(response.body).to include("続きの検索や詳細確認は既存管理画面で行えます。")
    expect(response.body).to include(admin_projects_path)
    expect(response.body).to include(project.code)
    expect(response.body).to include(project.name)
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

  it "shows an empty state when the model page has no recent records" do
    sign_in_as(admin_user)
    get admin_model_browser_model_path("documents")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最近のデータ")
    expect(response.body).to include("最近のデータはまだありません。")
    expect(response.body).to include("対象モデルに表示できるデータが登録されると、ここに代表データが表示されます。")
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
