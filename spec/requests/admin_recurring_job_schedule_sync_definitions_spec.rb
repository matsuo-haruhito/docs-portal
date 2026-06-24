require "rails_helper"

RSpec.describe "Admin recurring job schedule definition sync", type: :request do
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

  def hidden_value(form, name)
    form.at_css(%(input[type="hidden"][name="#{name}"]))&.[]("value")
  end

  def create_schedule!(attributes = {})
    defaults = {
      job_key: "sample_recurring_job",
      job_class: "SampleRecurringJob",
      queue_name: "default",
      interval_seconds: 3600,
      next_run_at: 1.hour.from_now
    }

    RecurringJobSchedule.create!(defaults.merge(attributes))
  end

  it "does not run definition sync from the legacy GET query param" do
    create_schedule!(job_key: "daily_report_job")
    allow(RecurringJobDispatcherJob).to receive(:perform_now)
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path(sync_definitions: 1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("daily_report_job")
    expect(RecurringJobDispatcherJob).not_to have_received(:perform_now)
  end

  it "renders visible sync controls as explicit POST forms" do
    create_schedule!(job_key: "visible_sync_job")
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path

    expect(response).to have_http_status(:ok)
    expect(sync_definition_forms.size).to eq(1)
    expect(sync_definition_forms.first.text).to include("定義を同期")
    expect(legacy_sync_links).to be_empty
  end

  it "passes the current filters through visible sync controls" do
    create_schedule!(job_key: "visible_sync_job", enabled: false, last_status: "failed")
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path(status: "failed", enabled: "false", q: " visible ")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("visible_sync_job")
    expect(sync_definition_forms.size).to eq(1)
    form = sync_definition_forms.first
    expect(hidden_value(form, "status")).to eq("failed")
    expect(hidden_value(form, "enabled")).to eq("false")
    expect(hidden_value(form, "q")).to eq("visible")
    expect(hidden_value(form, "return_to")).to be_nil
    expect(legacy_sync_links).to be_empty
  end

  it "keeps the sync form scoped when filters produce an empty table" do
    create_schedule!(job_key: "healthy_job", enabled: true, last_status: "completed")
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path(status: "failed", enabled: "false", q: "missing")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("条件に一致する定期ジョブはありません。")
    expect(parsed_html.text.squish).to include("表示中: 0件")
    expect(sync_definition_forms.size).to eq(1)
    form = sync_definition_forms.first
    expect(hidden_value(form, "status")).to eq("failed")
    expect(hidden_value(form, "enabled")).to eq("false")
    expect(hidden_value(form, "q")).to eq("missing")
  end

  it "uses the same POST sync action in the empty state" do
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("登録済みの定期ジョブはありません")
    expect(sync_definition_forms.size).to eq(2)
    expect(legacy_sync_links).to be_empty
  end

  it "runs definition sync only through the POST action" do
    allow(RecurringJobDispatcherJob).to receive(:perform_now)
    sign_in_as(admin_user)

    post sync_definitions_admin_recurring_job_schedules_path

    expect(response).to redirect_to(admin_recurring_job_schedules_path)
    expect(flash[:notice]).to eq("定期ジョブ定義を同期しました。")
    expect(RecurringJobDispatcherJob).to have_received(:perform_now).once
  end

  it "returns to the filtered list using only allowed filter params" do
    allow(RecurringJobDispatcherJob).to receive(:perform_now)
    sign_in_as(admin_user)

    post sync_definitions_admin_recurring_job_schedules_path, params: {
      status: "failed",
      enabled: "false",
      q: " queue error ",
      return_to: "https://example.com/unsafe",
      token: "secret-value"
    }

    expect(response).to redirect_to(admin_recurring_job_schedules_path(status: "failed", enabled: "false", q: "queue error"))
    expect(RecurringJobDispatcherJob).to have_received(:perform_now).once
  end

  it "drops unsupported filter values after sync" do
    allow(RecurringJobDispatcherJob).to receive(:perform_now)
    sign_in_as(admin_user)

    post sync_definitions_admin_recurring_job_schedules_path, params: {
      status: "unsupported",
      enabled: "maybe",
      q: "  "
    }

    expect(response).to redirect_to(admin_recurring_job_schedules_path)
    expect(RecurringJobDispatcherJob).to have_received(:perform_now).once
  end
end
