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
    expect(parsed_html.at_css(%(select[name="project_id"]))).to be_present
    expect(parsed_html.at_css(%(select[name="consent_term_id"]))).to be_present
    expect(parsed_html.at_css(%(select[name="enabled"]))).to be_present
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
end
