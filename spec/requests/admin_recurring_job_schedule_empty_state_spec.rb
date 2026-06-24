require "rails_helper"

RSpec.describe "Admin recurring job schedule empty state priority", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows the unregistered empty state before table preferences when no schedules exist" do
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("登録済みの定期ジョブはありません。定義を同期すると、dispatcher 定義に基づいて登録されます。")
    expect(page_text).to include("列の表示設定は行があるときに調整してください。")
    expect(response.body).not_to include("定期ジョブ一覧の表示設定")
    expect(parsed_html.css("tbody tr")).to be_empty
    expect(sync_definition_forms.size).to eq(2)
    expect(legacy_sync_links).to be_empty
  end

  it "keeps the table context for filtered empty results" do
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する定期ジョブはありません。")
    expect(response.body).to include("定期ジョブ一覧の表示設定")
    expect(parsed_html.at_css("tbody tr td").text).to include("条件に一致する定期ジョブはありません。")
    expect(response.body).to include("絞り込み解除")
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def sync_definition_forms
    parsed_html.css(%(form[action="#{sync_definitions_admin_recurring_job_schedules_path}"][method="post"]))
  end

  def legacy_sync_links
    parsed_html.css(%(a[href="#{admin_recurring_job_schedules_path(sync_definitions: 1)}"]))
  end
end
