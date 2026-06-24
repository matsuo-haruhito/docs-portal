require "rails_helper"

RSpec.describe "Admin recurring job schedule empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def sync_definition_forms
    parsed_html.css(%(form[action="#{sync_definitions_admin_recurring_job_schedules_path}"][method="post"]))
  end

  def legacy_sync_links
    parsed_html.css(%(a[href="#{admin_recurring_job_schedules_path(sync_definitions: 1)}"]))
  end

  it "shows a reset link in the filtered empty state" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "invoice_digest", job_class: "InvoiceDigestJob", last_status: "completed", enabled: false)
    create_schedule!(job_key: "billing_worker", job_class: "BillingWorkerJob", last_status: "failed", enabled: true)

    get admin_recurring_job_schedules_path(status: "failed", enabled: "false", q: "invoice")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("表示中: 0件")
    expect(response.body).to include("条件に一致する定期ジョブはありません。")
    expect(response.body).to include("条件を見直すか、すべての定期ジョブを表示してください。")
    reset_link = parsed_html.at_css(%(tbody a[href="#{admin_recurring_job_schedules_path}"]))
    expect(reset_link).to be_present
    expect(reset_link.text.squish).to eq("すべての定期ジョブを見る")
  end

  it "keeps the initial empty state focused on syncing definitions" do
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("表示中: 0件")
    expect(response.body).to include("登録済みの定期ジョブはありません。定義を同期すると、dispatcher 定義に基づいて登録されます。")
    expect(response.body).to include("登録後に、前回状態・有効状態・検索条件で一覧を確認できます。")
    expect(sync_definition_forms.size).to eq(2)
    expect(legacy_sync_links).to be_empty
    expect(response.body).not_to include("すべての定期ジョブを見る")
  end

  def create_schedule!(attributes = {})
    defaults = {
      job_key: "sample_job",
      job_class: "SampleJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: 1.hour.from_now,
      enabled: true,
      allow_overlap: false,
      args_json: []
    }

    RecurringJobSchedule.create!(defaults.merge(attributes))
  end
end
