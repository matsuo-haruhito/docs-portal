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

  def model_browser_cards
    parsed_html.css(".model-browser-group .metric-card")
  end

  def page_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
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
    expect(response.body).to include("取り込み・同期")
    expect(response.body).to include("外部連携")
    expect(response.body).to include("運用")
    expect(response.body).to include("案件")
    expect(response.body).to include("文書")
    expect(response.body).to include("key: projects / group: 基本マスタ")
    expect(response.body).to include("key: documents / group: 文書・権限")
    expect(response.body).to include("key: git_import_sources / group: 取り込み・同期")
    expect(response.body).to include("この検索は catalog entry のモデル名、key、説明、group を対象にします。")
    expect(response.body).to include("record 名、public_id、code の確認は各 model の詳細または既存画面で続けてください。")
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
    expect(card_hrefs).to include(admin_model_browser_model_path("documents", model_browser_q: "文書"))
    expect(card_hrefs).not_to include(admin_model_browser_model_path("companies", model_browser_q: "文書"))
  end

  it "returns from a searched model detail to the original model browser index query" do
    sign_in_as(admin_user)
    get admin_model_browser_model_path("documents"), params: { model_browser_q: "文書" }

    expect(response).to have_http_status(:ok)
    expect(page_hrefs).to include(admin_model_browser_path(q: "文書"))
    expect(parsed_html.css("input[name='model_browser_q'][value='文書']")).to be_present
    expect(page_hrefs).not_to include(admin_model_browser_model_path("documents", model_browser_q: "文書"))
    expect(page_hrefs).not_to include(admin_model_browser_path(q: "documents"))
  end

  it "normalizes and bounds model browser index return context independently from record searches" do
    overlong_return_context = "  文書" + ("x" * 120)
    bounded_return_context = overlong_return_context.strip.slice(0, Admin::ModelBrowsersController::MODEL_BROWSER_QUERY_MAX_LENGTH)

    sign_in_as(admin_user)
    get admin_model_browser_model_path("documents"), params: { model_browser_q: overlong_return_context, q: "release-note" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索語: release-note / 最大20件の代表表示です。")
    expect(response.body).to include("検索を解除")
    expect(parsed_html.css("input[name='model_browser_q'][value='#{bounded_return_context}']")).to be_present
    expect(page_hrefs).to include(admin_model_browser_path(q: bounded_return_context))
    expect(page_hrefs).to include(admin_model_browser_model_path("documents", model_browser_q: bounded_return_context))
    expect(page_hrefs).not_to include(admin_model_browser_path(q: "release-note"))
    expect(response.body).not_to include(overlong_return_context.strip)
  end

  it "keeps model browser index return context separate from model record searches" do
    matching_project = create(:project, code: "RETURN2389", name: "Return Context Project")
    other_project = create(:project, code: "OTHER2389", name: "Other Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects"), params: { model_browser_q: "文書", q: "Return" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("検索語: Return / 最大20件の代表表示です。")
    expect(response.body).to include("20件より先や詳細確認は「既存画面で詳しく確認」から続けてください。")
    expect(parsed_html.css("input[name='model_browser_q'][value='文書']")).to be_present
    expect(page_hrefs).to include(admin_model_browser_path(q: "文書"))
    expect(page_hrefs).to include(admin_projects_path(q: "Return"))
    expect(page_hrefs).not_to include(admin_model_browser_path(q: "Return"))
    expect(response.body).to include(matching_project.code)
    expect(response.body).not_to include(other_project.code)
  end

  it "falls back to the model browser index for unsafe return context values" do
    unsafe_return_contexts = [
      "http://example.com/admin",
      "https://example.com/admin",
      "//example.com/admin",
      "/admin/projects"
    ]

    sign_in_as(admin_user)

    unsafe_return_contexts.each do |unsafe_return_context|
      get admin_model_browser_model_path("documents"), params: { model_browser_q: unsafe_return_context, q: "doc" }

      expect(response).to have_http_status(:ok)
      expect(page_hrefs).to include(admin_model_browser_path)
      expect(page_hrefs).not_to include(admin_model_browser_path(q: unsafe_return_context))
      expect(response.body).not_to include(unsafe_return_context) if unsafe_return_context.match?(%r{\Ahttps?://})
    end
  end

  it "filters the model browser index by key while normalizing spaces and case" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "  DOCUMENT_FILES  " }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件: DOCUMENT_FILES")

    card_labels = model_browser_card_links.map { _1.text.squish }
    card_hrefs = model_browser_card_links.map { _1["href"] }
    card_texts = model_browser_cards.map { _1.text.squish }

    expect(card_labels).to eq(["文書ファイル"])
    expect(card_hrefs).to eq([admin_model_browser_model_path("document_files", model_browser_q: "DOCUMENT_FILES")])
    expect(card_texts).to contain_exactly(include("key: document_files / group: 文書・権限"))
  end

  it "treats blank model browser index queries as no-op filters" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "   " }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("検索条件:")
    expect(response.body).not_to include("検索条件に一致するモデルはありません。")
    expect(response.body).not_to include("検索解除")

    card_hrefs = model_browser_card_links.map { _1["href"] }
    expect(card_hrefs).to include(admin_model_browser_model_path("companies"))
    expect(card_hrefs).to include(admin_model_browser_model_path("documents"))
  end

  it "bounds overlong model browser index queries before display and filtering" do
    overlong_query = "x" * 120
    bounded_query = "x" * Admin::ModelBrowsersController::MODEL_BROWSER_QUERY_MAX_LENGTH

    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: overlong_query }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件: #{bounded_query} / 表示中: 0件")
    expect(response.body).not_to include(overlong_query)
    expect(response.body).to include("検索条件に一致するモデルはありません。")
    expect(page_hrefs).to include(admin_model_browser_path)
    expect(model_browser_card_links).to be_empty
  end

  it "filters the model browser index by description and group label" do
    sign_in_as(admin_user)

    get admin_model_browser_path, params: { q: "公開単位" }
    expect(response).to have_http_status(:ok)
    expect(model_browser_card_links.map { _1["href"] }).to include(admin_model_browser_model_path("projects", model_browser_q: "公開単位"))

    get admin_model_browser_path, params: { q: "取り込み" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("取り込み・同期")
    expect(model_browser_card_links.map { _1["href"] }).to include(admin_model_browser_model_path("git_import_sources", model_browser_q: "取り込み"))
  end

  it "shows a search empty state on the model browser index" do
    sign_in_as(admin_user)
    get admin_model_browser_path, params: { q: "missing catalog entry" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件に一致するモデルはありません。")
    expect(response.body).to include("モデル名、key、説明、group の表記を変えて再検索してください。")
    expect(response.body).to include("この検索は model catalog entry の検索です。")
    expect(response.body).to include("record 名、public_id、code を探す場合は、対象 model の詳細に進んで「代表フィールド検索」を使うか、既存管理画面で確認してください。")
    expect(response.body).to include("一覧に出る model 自体が見つからない状態")
    expect(response.body).to include("record が存在しないことや既存画面で検索できないことを示すものではありません。")
    expect(page_hrefs).to include(admin_model_browser_path)
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
    expect(response.body).to include("代表フィールド検索")
    expect(response.body).to include("最近のデータ")
    expect(response.body).to include("最新の代表データを最大20件まで表示します。この画面では編集や削除はできません。")
    expect(response.body).to include("この画面は最近の代表データや検索結果を最大20件だけ確認するための read-only 表示です。")
    expect(response.body).to include("検索対象フィールドに一致した代表データだけを表示し、20件より先の確認や詳細確認は既存管理画面で行えます。")
    expect(response.body).to include("検索結果は検索対象フィールドに一致した代表データを最大20件まで表示します。")
    expect(response.body).to include("数値だけの検索語は、この画面では ID 補助照合にも使います。")
    expect(response.body).to include("既存画面で詳しく確認")
    expect(response.body).to include("20件より先や詳細確認は「既存画面で詳しく確認」から続けてください。")
    expect(response.body).not_to include("検索語「")
    expect(response.body).not_to include("検索を解除")
    expect(response.body).to include(admin_projects_path)
    expect(response.body).to include(project.code)
    expect(response.body).to include(project.name)
  end

  it "filters model pages by whitelisted text summary fields and hands the query to compatible admin indexes" do
    matching_project = create(:project, code: "SEARCH1674", name: "Needle Project")
    other_project = create(:project, code: "OTHER1674", name: "Other Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects"), params: { q: "Needle" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("検索語: Needle / 最大20件の代表表示です。")
    expect(response.body).to include("20件より先や詳細確認は「既存画面で詳しく確認」から続けてください。")
    expect(response.body).to include("「既存画面で詳しく確認」は検索語「Needle」を既存画面の検索条件として渡します。")
    expect(response.body).to include("検索を解除")
    expect(page_hrefs).to include(admin_model_browser_model_path("projects"))
    expect(page_hrefs).to include(admin_projects_path(q: "Needle"))
    expect(response.body).to include("検索対象:")
    expect(response.body).to include("コード")
    expect(response.body).to include("検索結果は検索対象フィールドに一致した代表データを最大20件まで表示します。")
    expect(response.body).to include(matching_project.code)
    expect(response.body).to include(matching_project.name)
    expect(response.body).not_to include(other_project.code)
    expect(response.body).not_to include(other_project.name)
  end

  it "does not show existing screen search guidance when the model has no index path" do
    sign_in_as(admin_user)
    get admin_model_browser_model_path("document_versions"), params: { q: "release-note" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("検索語: release-note / 最大20件の代表表示です。")
    expect(response.body).not_to include("既存画面で詳しく確認")
    expect(response.body).not_to include("20件より先や詳細確認は「既存画面で詳しく確認」")
    expect(response.body).not_to include("既存画面で続けて確認する場合")
  end

  it "keeps unsupported existing screen links without query handoff" do
    sign_in_as(admin_user)
    get admin_model_browser_model_path("document_permissions"), params: { q: "download" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("既存画面で詳しく確認")
    expect(response.body).to include("既存画面で続けて確認する場合は、検索語「download」をコピーして")
    expect(page_hrefs).to include(admin_document_permissions_path)
    expect(page_hrefs).not_to include(admin_document_permissions_path(q: "download"))
  end

  it "matches numeric queries against id without adding write actions or query handoff" do
    matching_project = create(:project, code: "IDMATCH1674", name: "ID Match Project")
    other_project = create(:project, code: "IDOTHER1674", name: "ID Other Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects"), params: { q: matching_project.id.to_s }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_project.code)
    expect(response.body).to include("数値だけの検索語はこの read-only 画面の ID 照合にも使われる")
    expect(response.body).to include("数値だけの検索語は、この画面では ID 補助照合にも使います。")
    expect(page_hrefs).to include(admin_projects_path)
    expect(page_hrefs).not_to include(admin_projects_path(q: matching_project.id.to_s))
    expect(response.body).not_to include(other_project.code)

    action_labels = parsed_html.css("a, button, input[type='submit']").map { _1.text.presence || _1["value"] }.compact.map(&:squish)
    expect(action_labels).not_to include("削除")
  end

  it "shows an empty state for searches with no matching records" do
    project = create(:project, code: "MISS1674", name: "Miss Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects"), params: { q: "NO_MATCH_1674" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("該当する代表データはありません。")
    expect(response.body).to include("検索対象は")
    expect(response.body).to include("コード")
    expect(response.body).to include("表示は最大20件の read-only sample です。")
    expect(response.body).to include("既存画面でも同じ検索語で確認できます。")
    expect(response.body).to include("20件より先や別条件の確認は「既存画面で詳しく確認」から続けてください。")
    expect(page_hrefs).to include(admin_projects_path(q: "NO_MATCH_1674"))
    expect(response.body).not_to include(project.code)
  end

  it "handles overlong symbol queries without raising an error" do
    create(:project, code: "SYMBOL1674", name: "Symbol Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects"), params: { q: "!'" * 120 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果")
    expect(response.body).to include("該当する代表データはありません。")
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
