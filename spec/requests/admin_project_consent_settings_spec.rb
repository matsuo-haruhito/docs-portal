require "rails_helper"

RSpec.describe "Admin project consent settings", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  it "filters settings by project, consent term, and enabled state" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    beta_project = create(:project, code: "BETA", name: "Beta Project")
    portal_terms = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    security_terms = create(:consent_term, title: "Security NDA", version_label: "v2", consent_scope: :project)
    create(:project_consent_setting, project: alpha_project, consent_term: portal_terms, enabled: true)
    create(:project_consent_setting, project: beta_project, consent_term: portal_terms, enabled: true)
    create(:project_consent_setting, project: alpha_project, consent_term: security_terms, enabled: false)

    get admin_project_consent_settings_path(project_id: alpha_project.id, consent_term_id: portal_terms.id, enabled: "true")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("必須タイミングは、閲覧前・ダウンロード前が現在の必須化対象です。")
    expect(response.body).to include("共有リンク系の（予約）は将来拡張用")
    expect(response.body).to include("検索結果: 1件")
    expect(response.body).to include("表示中: 1-1件 / 1件")
    expect(listed_rows).to contain_exactly(a_string_including("Alpha Project", "Portal Terms", "有効"))
    expect(listed_rows.join).not_to include("Beta Project")
    expect(listed_rows.join).not_to include("Security NDA")
    expect(project_filter).to be_present
    expect(consent_term_filter).to be_present
    expect(enabled_filter).to be_present
    expect(enabled_filter_field).to be_present
    expect(enabled_filter_field.at_css("label")&.text&.squish).to eq("状態")
    expect(enabled_filter_in_field&.[]("name")).to eq("enabled")
    expect(enabled_filter_in_field&.[]("onchange")).to eq("this.form.requestSubmit()")
    expect(selected_value(project_filter)).to eq(alpha_project.id.to_s)
    expect(selected_value(consent_term_filter)).to eq(portal_terms.id.to_s)
    expect(response.body).to include("案件コード・案件名で検索", "同意文面名・版で検索")
    expect(response.body).to include(project_search_admin_project_consent_settings_path(format: :json))
    expect(response.body).to include(consent_term_search_admin_project_consent_settings_path(format: :json))
  end

  it "filters disabled settings and ignores unsupported filter values safely" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    beta_project = create(:project, code: "BETA", name: "Beta Project")
    portal_terms = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    security_terms = create(:consent_term, title: "Security NDA", version_label: "v2", consent_scope: :project)
    create(:project_consent_setting, project: alpha_project, consent_term: portal_terms, enabled: true)
    create(:project_consent_setting, project: beta_project, consent_term: security_terms, enabled: false)

    get admin_project_consent_settings_path(enabled: "false")

    expect(response).to have_http_status(:ok)
    expect(listed_rows).to contain_exactly(a_string_including("Beta Project", "Security NDA", "無効"))

    get admin_project_consent_settings_path(project_id: "999999", consent_term_id: "999999", enabled: "archived")

    expect(response).to have_http_status(:ok)
    expect(listed_rows.size).to eq(2)
    expect(response.body).not_to include("絞り込み解除")
    expect(selected_value(project_filter)).to be_nil
    expect(selected_value(consent_term_filter)).to be_nil
  end

  it "keeps inactive consent term settings visible while ignoring inactive term filters" do
    active_project = create(:project, code: "ACTIVE", name: "Active Project")
    archived_project = create(:project, code: "ARCH", name: "Archived Project")
    active_terms = create(:consent_term, title: "Active Portal Terms", version_label: "v1", consent_scope: :project)
    inactive_terms = create(:consent_term, title: "Archived Portal Terms", version_label: "old", consent_scope: :project, active: false)
    create(:project_consent_setting, project: active_project, consent_term: active_terms, enabled: true)
    create(:project_consent_setting, project: archived_project, consent_term: inactive_terms, enabled: true)

    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    expect(listed_rows).to contain_exactly(
      a_string_including("Active Project", "Active Portal Terms", "有効"),
      a_string_including("Archived Project", "Archived Portal Terms", "有効")
    )

    get admin_project_consent_settings_path(consent_term_id: inactive_terms.id)

    expect(response).to have_http_status(:ok)
    expect(listed_rows).to contain_exactly(
      a_string_including("Active Project", "Active Portal Terms", "有効"),
      a_string_including("Archived Project", "Archived Portal Terms", "有効")
    )
    expect(response.body).not_to include("絞り込み解除")
    expect(selected_value(consent_term_filter)).to be_nil
  end

  it "keeps inactive consent term labels on existing edit and validation rerender" do
    project = create(:project, code: "ARCH", name: "Archived Project")
    inactive_terms = create(:consent_term, title: "Archived Portal Terms", version_label: "old", consent_scope: :project, active: false)
    setting = create(:project_consent_setting, project:, consent_term: inactive_terms, enabled: true)

    get edit_admin_project_consent_setting_path(setting)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Archived Portal Terms / old")
    expect(selected_value(consent_term_field)).to eq(inactive_terms.id.to_s)

    post admin_project_consent_settings_path, params: {
      project_consent_setting: {
        project_id: project.id,
        consent_term_id: inactive_terms.id,
        required_on: "",
        enabled: true
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Archived Portal Terms / old")
    expect(selected_value(consent_term_field)).to eq(inactive_terms.id.to_s)
  end

  it "marks inactive consent terms separately from the setting enabled state" do
    active_project = create(:project, code: "ACTIVE", name: "Active Project")
    archived_project = create(:project, code: "ARCH", name: "Archived Project")
    active_terms = create(:consent_term, title: "Current Terms", version_label: "v1", consent_scope: :project, active: true)
    inactive_terms = create(:consent_term, title: "Archived Terms", version_label: "old", consent_scope: :project, active: false)
    create(:project_consent_setting, project: active_project, consent_term: active_terms, enabled: true)
    create(:project_consent_setting, project: archived_project, consent_term: inactive_terms, enabled: true)

    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    active_cell = consent_term_cells.find { _1.include?("Current Terms") }
    inactive_cell = consent_term_cells.find { _1.include?("Archived Terms") }
    expect(active_cell).to be_present
    expect(active_cell).not_to include("同意文面: 無効化済み")
    expect(inactive_cell).to include("同意文面: 無効化済み")
    expect(listed_rows.find { _1.include?("Archived Project") }).to include("有効")
  end

  it "returns bounded remote search options for projects and active consent terms" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    beta_project = create(:project, code: "BETA", name: "Beta Project")
    portal_terms = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    security_terms = create(:consent_term, title: "Security NDA", version_label: "v2", consent_scope: :project)
    inactive_terms = create(:consent_term, title: "Archived Portal Terms", version_label: "old", consent_scope: :project, active: false)

    get project_search_admin_project_consent_settings_path(format: :json), params: { q: "alp" }

    expect(response).to have_http_status(:ok)
    project_options = JSON.parse(response.body).fetch("options")
    expect(project_options).to contain_exactly(
      include("value" => alpha_project.id, "text" => "Alpha Project (ALPHA)")
    )
    expect(project_options.map { _1.fetch("text") }).not_to include("Beta Project (BETA)")

    get selected_project_admin_project_consent_settings_path(format: :json), params: { id: beta_project.id }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("option")).to include("value" => beta_project.id, "text" => "Beta Project (BETA)")

    get consent_term_search_admin_project_consent_settings_path(format: :json), params: { q: "terms" }

    expect(response).to have_http_status(:ok)
    consent_term_options = JSON.parse(response.body).fetch("options")
    expect(consent_term_options).to contain_exactly(
      include("value" => portal_terms.id, "text" => "Portal Terms / v1")
    )
    expect(consent_term_options.map { _1.fetch("value") }).not_to include(inactive_terms.id)

    get selected_consent_term_admin_project_consent_settings_path(format: :json), params: { id: security_terms.id }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("option")).to include("value" => security_terms.id, "text" => "Security NDA / v2")

    get selected_consent_term_admin_project_consent_settings_path(format: :json), params: { id: inactive_terms.id }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("option")).to be_nil
  end

  it "bounds remote search results and query lengths" do
    22.times do |index|
      create(:project, code: format("PRJ%02d", index), name: "Searchable Project #{index}")
      create(:consent_term, title: "Searchable Terms #{index}", version_label: format("v%02d", index), consent_scope: :project)
    end

    get project_search_admin_project_consent_settings_path(format: :json), params: { q: "Searchable Project" }
    expect(JSON.parse(response.body).fetch("options").size).to eq(Admin::ProjectConsentSettingsController::PROJECT_SEARCH_LIMIT)

    long_query = "Searchable Terms" + ("x" * 200)
    get consent_term_search_admin_project_consent_settings_path(format: :json), params: { q: long_query }
    expect(JSON.parse(response.body).fetch("options")).to eq([])
  end

  it "paginates settings with the default admin page size" do
    create_project_consent_settings(26)

    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("表示中: 1-25件 / 26件")
    expect(listed_rows.size).to eq(25)
    expect(listed_rows.join).to include("Project 00", "Project 24")
    expect(listed_rows.join).not_to include("Project 25")
    expect(pagination_label).to eq("1 / 2ページ")
    expect(pagination_link("次へ")["href"]).to include("page=2")
  end

  it "keeps filters and bounded per-page values in pagination links" do
    create_project_consent_settings(27, enabled: true)

    get admin_project_consent_settings_path(enabled: "true", page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果: 27件")
    expect(response.body).to include("表示中: 26-27件 / 27件")
    expect(listed_rows).to contain_exactly(
      a_string_including("Project 25", "有効"),
      a_string_including("Project 26", "有効")
    )
    expect(selected_value(enabled_filter)).to eq("true")
    expect(pagination_label).to eq("2 / 2ページ")
    expect(pagination_link("前へ")["href"]).to include("enabled=true", "page=1")
  end

  it "bounds invalid page values with the shared admin pagination rules" do
    create_project_consent_settings(26, enabled: true)

    get admin_project_consent_settings_path(enabled: "true", page: 999, per_page: 10)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("表示中: 21-26件 / 26件")
    expect(listed_rows.size).to eq(6)
    expect(pagination_label).to eq("3 / 3ページ")
    expect(pagination_link("前へ")["href"]).to include("enabled=true", "per_page=10", "page=2")
    expect(pagination_link("次へ")).to be_nil
  end

  it "shows a filtered empty state separately from the unregistered empty state" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    beta_project = create(:project, code: "BETA", name: "Beta Project")
    portal_terms = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    create(:project_consent_setting, project: alpha_project, consent_term: portal_terms, enabled: true)

    get admin_project_consent_settings_path(project_id: beta_project.id, enabled: "true")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索結果: 0件")
    expect(response.body).to include("表示中: 0件")
    expect(response.body).to include("条件に一致する案件同意設定はありません。")
    expect(response.body).to include("絞り込み解除")
    expect(response.body).not_to include("先に「同意文面管理」で有効な文面を用意")
    expect(selected_value(project_filter)).to eq(beta_project.id.to_s)
  end

  it "keeps the existing unregistered empty state when no filters or settings exist" do
    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("表示中: 0件")
    expect(response.body).to include("まだ案件同意設定はありません。")
    expect(response.body).to include("先に「同意文面管理」で有効な文面を用意")
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def listed_rows
    parsed_html.css("tbody tr").map { |row| row.text.squish }
  end

  def consent_term_cells
    parsed_html.css('td[data-rails-table-preferences-column-key="consent_term"]').map { |cell| cell.text.squish }
  end

  def project_filter
    parsed_html.at_css(%(input[name="project_id"])) || parsed_html.at_css(%(select[name="project_id"]))
  end

  def consent_term_filter
    parsed_html.at_css(%(input[name="consent_term_id"])) || parsed_html.at_css(%(select[name="consent_term_id"]))
  end

  def consent_term_field
    parsed_html.at_css(%(input[name="project_consent_setting[consent_term_id]"])) ||
      parsed_html.at_css(%(select[name="project_consent_setting[consent_term_id]"]))
  end

  def enabled_filter
    parsed_html.at_css(%(select[name="enabled"]))
  end

  def enabled_filter_field
    enabled_filter&.ancestors&.find { |node| node["class"].to_s.split.include?("field") }
  end

  def enabled_filter_in_field
    enabled_filter_field&.at_css(%(select[name="enabled"]))
  end

  def selected_value(node)
    node&.[]("value").presence || node&.at_css("option[selected]")&.[]("value")
  end

  def pagination_label
    parsed_html.at_css("nav.pagination span.muted")&.text&.squish
  end

  def pagination_link(label)
    parsed_html.css("nav.pagination a").find { |link| link.text.squish == label }
  end

  def create_project_consent_settings(count, enabled: true)
    consent_term = create(:consent_term, title: "Paged Terms", version_label: "v1", consent_scope: :project)
    count.times do |index|
      project = create(:project, code: format("P%02d", index), name: format("Project %02d", index))
      create(:project_consent_setting, project:, consent_term:, enabled:)
    end
  end
end
