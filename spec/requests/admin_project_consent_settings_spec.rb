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
    expect(project_filter.text.squish).to include("Alpha Project (ALPHA)", "Beta Project (BETA)")
    expect(consent_term_filter.text.squish).to include("Portal Terms / v1", "Security NDA / v2")
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

  it "shows a filtered empty state separately from the unregistered empty state" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    beta_project = create(:project, code: "BETA", name: "Beta Project")
    portal_terms = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    create(:project_consent_setting, project: alpha_project, consent_term: portal_terms, enabled: true)

    get admin_project_consent_settings_path(project_id: beta_project.id, enabled: "true")

    expect(response).to have_http_status(:ok)
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

  def project_filter
    parsed_html.at_css(%(select[name="project_id"]))
  end

  def consent_term_filter
    parsed_html.at_css(%(select[name="consent_term_id"]))
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

  def selected_value(select_node)
    select_node&.at_css("option[selected]")&.[]("value")
  end
end
