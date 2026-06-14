require "rails_helper"

RSpec.describe "Admin project consent setting filtered empty state reset", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  it "shows a table reset link when filters remove all settings" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    beta_project = create(:project, code: "BETA", name: "Beta Project")
    consent_term = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    create(:project_consent_setting, project: alpha_project, consent_term:, enabled: true)

    get admin_project_consent_settings_path(project_id: beta_project.id, enabled: "true")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 0件")
    expect(page_text).to include("条件に一致する案件同意設定はありません。")
    expect(page_text).to include("条件を見直すか、すべての案件同意設定を表示してください。")

    reset_link = parsed_html.at_css(%(tbody a[href="#{admin_project_consent_settings_path}"]))
    expect(reset_link).to be_present
    expect(reset_link.text.squish).to eq("すべての案件同意設定を見る")
  end

  it "keeps the initial empty state free of filter reset links" do
    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ案件同意設定はありません。")
    expect(parsed_html.at_css(%(tbody a[href="#{admin_project_consent_settings_path}"]))).to be_nil
    expect(page_text).not_to include("すべての案件同意設定を見る")
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end
end
