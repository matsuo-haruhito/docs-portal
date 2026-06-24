require "rails_helper"

RSpec.describe "Admin recurring job schedules", type: :request do
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

  it "filters schedules by previous status while keeping the sync action available" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "failed_job", last_status: "failed")
    create_schedule!(job_key: "completed_job", last_status: "completed")
    create_schedule!(job_key: "not_run_job", last_status: nil)

    get admin_recurring_job_schedules_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["failed_job"])
    expect(sync_definition_forms.size).to eq(1)
    expect(legacy_sync_links).to be_empty
    expect(response.body).to include("前回状態 filter は直近実行結果で絞り込みます。")
    expect(response.body).to include("定義の有効/無効は「定義状態」列または有効状態 filter で確認してください。")
    expect(response.body).to include("Triage対象（前回状態ベース）: 失敗: 1件 / 実行中: 0件 / キュー待ち: 0件")
    expect(parsed_html.at_css(%(th[data-rails-table-preferences-column-key="status"])).text).to eq("定義状態")
    expect(parsed_html.at_css(%(th[data-rails-table-preferences-column-key="last_status"])).text).to eq("前回状態")
  end

  it "ignores invalid schedule status filters" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "failed_job", last_status: "failed")
    create_schedule!(job_key: "completed_job", last_status: "completed")
    create_schedule!(job_key: "not_run_job", last_status: nil)

    get admin_recurring_job_schedules_path(status: "archived")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["completed_job", "failed_job", "not_run_job"])
  end

  it "filters schedules by enabled state" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "enabled_digest", enabled: true)
    create_schedule!(job_key: "disabled_cleanup", enabled: false)

    get admin_recurring_job_schedules_path(enabled: "true")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["enabled_digest"])
    expect(response.body).to include("有効状態")
    expect(parsed_html.at_css(%(select[name="enabled"] option[value="true"][selected]))).to be_present

    get admin_recurring_job_schedules_path(enabled: "false")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["disabled_cleanup"])
    expect(parsed_html.at_css(%(select[name="enabled"] option[value="false"][selected]))).to be_present
  end

  it "ignores invalid enabled filters" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "enabled_digest", enabled: true)
    create_schedule!(job_key: "disabled_cleanup", enabled: false)

    get admin_recurring_job_schedules_path(enabled: "archived")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["disabled_cleanup", "enabled_digest"])
  end

  it "filters schedules by job key, job class, queue, and previous error fragments" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "daily_report_export", job_class: "ReportExportJob", queue_name: "default", last_error_message: "timeout while exporting")
    create_schedule!(job_key: "stale_cleanup", job_class: "CleanupJob", queue_name: "maintenance")
    create_schedule!(job_key: "mail_delivery", job_class: "MailDeliveryJob", queue_name: "critical_mailers")

    get admin_recurring_job_schedules_path(q: "REPORT")
    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["daily_report_export"])

    get admin_recurring_job_schedules_path(q: "CleanupJob")
    expect(listed_schedule_keys).to eq(["stale_cleanup"])

    get admin_recurring_job_schedules_path(q: "mailers")
    expect(listed_schedule_keys).to eq(["mail_delivery"])

    get admin_recurring_job_schedules_path(q: "timeout")
    expect(listed_schedule_keys).to eq(["daily_report_export"])
  end

  it "combines schedule search with previous status and enabled state while keeping the list return path" do
    sign_in_as(admin_user)
    target = create_schedule!(job_key: "invoice_digest", job_class: "InvoiceDigestJob", last_status: "failed", enabled: false)
    create_schedule!(job_key: "invoice_enabled", job_class: "InvoiceDigestJob", last_status: "failed", enabled: true)
    create_schedule!(job_key: "invoice_completed", job_class: "InvoiceDigestJob", last_status: "completed", enabled: false)
    create_schedule!(job_key: "billing_worker", job_class: "BillingWorkerJob", last_status: "failed", enabled: false)

    list_path = admin_recurring_job_schedules_path(status: "failed", enabled: "false", q: "invoice")
    get list_path

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["invoice_digest"])
    expect(response.body).to include("表示中: 1件")
    expect(parsed_html.at_css(%(input[name="q"][value="invoice"]))).to be_present
    expect(parsed_html.at_css(%(select[name="enabled"] option[value="false"][selected]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedule_path(target, return_to: list_path)}"]))).to be_present
  end

  it "shows the schedule search boundary and truncates long search fragments" do
    sign_in_as(admin_user)
    bounded_fragment = "a" * Admin::RecurringJobSchedulesController::SCHEDULE_QUERY_MAX_LENGTH
    long_fragment = "  #{bounded_fragment}extra-error-log-tail  "
    create_schedule!(job_key: "bounded_error_job", last_error_message: bounded_fragment)

    get admin_recurring_job_schedules_path(q: long_fragment)

    expect(response).to have_http_status(:ok)
    search_input = parsed_html.at_css(%(input[name="q"]))
    expect(search_input).to be_present
    expect(search_input["maxlength"]).to eq(Admin::RecurringJobSchedulesController::SCHEDULE_QUERY_MAX_LENGTH.to_s)
    expect(search_input["value"]).to eq(bounded_fragment)
    expect(response.body).to include("検索はジョブキー / class / queue / 前回エラーの断片を最大#{Admin::RecurringJobSchedulesController::SCHEDULE_QUERY_MAX_LENGTH}文字で指定できます。")
    expect(response.body).to include("長い error log は全文ではなく特徴的な一部で探してください。")
    expect(listed_schedule_keys).to eq(["bounded_error_job"])
  end

  it "shows a filtered empty state when enabled state, search, and previous status match no schedules" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "invoice_digest", job_class: "InvoiceDigestJob", last_status: "completed", enabled: false)
    create_schedule!(job_key: "billing_worker", job_class: "BillingWorkerJob", last_status: "failed", enabled: true)

    get admin_recurring_job_schedules_path(status: "failed", enabled: "false", q: "invoice")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to be_empty
    expect(response.body).to include("表示中: 0件")
    expect(response.body).to include("条件に一致する定期ジョブはありません。")
    expect(response.body).to include("絞り込み解除")
  end

  it "shows an unregistered empty state when no schedules exist" do
    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to be_empty
    expect(response.body).to include("表示中: 0件")
    expect(response.body).to include("登録済みの定期ジョブはありません。定義を同期すると、dispatcher 定義に基づいて登録されます。")
    expect(sync_definition_forms.size).to eq(2)
    expect(legacy_sync_links).to be_empty
  end

  it "treats blank schedule search as an empty condition" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "alpha_job")
    create_schedule!(job_key: "beta_job")

    get admin_recurring_job_schedules_path(q: "   ")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["alpha_job", "beta_job"])
  end

  it "filters schedules with no previous run status" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "failed_job", last_status: "failed")
    create_schedule!(job_key: "not_run_job", last_status: nil)

    get admin_recurring_job_schedules_path(status: "not_run")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["not_run_job"])
  end

  it "paginates detail run history beyond the first 50 entries" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "history_pagination_job", last_status: "completed")
    create_run!(schedule, status: "completed", active_job_id: "oldest-run", scheduled_at: 2.days.ago)
    50.times do |index|
      create_run!(schedule, status: "completed", active_job_id: "recent-run-#{index}", scheduled_at: index.minutes.ago)
    end

    get admin_recurring_job_schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("recent-run-0")
    expect(response.body).to include("recent-run-49")
    expect(response.body).not_to include("oldest-run")
    expect(response.body).to include("表示中: 1-50件 / 全51件（50件ずつ、1/2ページ）")
    expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path, per_page: 50, page: 2)}"]))).to be_present

    get admin_recurring_job_schedule_path(schedule, page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("oldest-run")
    expect(response.body).not_to include("recent-run-49")
    expect(response.body).to include("表示中: 51-51件 / 全51件（50件ずつ、2/2ページ）")
  end

  it "keeps run filters and return_to on pagination links" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "filtered_history_page_job", last_status: "failed")
    scheduled_from = 3.days.ago.to_date.to_s
    scheduled_to = Time.zone.today.to_s
    list_path = admin_recurring_job_schedules_path(status: "failed", enabled: "false")
    51.times do |index|
      create_run!(schedule, status: "failed", active_job_id: format("matching-run-%03d", index), scheduled_at: index.minutes.ago)
    end
    create_run!(schedule, status: "completed", active_job_id: "completed-run", scheduled_at: 1.minute.ago)

    get admin_recurring_job_schedule_path(
      schedule,
      run_status: "failed",
      q: "matching",
      scheduled_from:,
      scheduled_to:,
      return_to: list_path
    )

    expect(response).to have_http_status(:ok)
    expected_next_path = admin_recurring_job_schedule_path(
      schedule,
      return_to: list_path,
      run_status: "failed",
      q: "matching",
      scheduled_from:,
      scheduled_to:,
      per_page: 50,
      page: 2
    )
    expect(parsed_html.at_css(%(a[href="#{expected_next_path}"]))).to be_present
    expect(parsed_html.at_css(%(input[name="return_to"][value="#{list_path}"]))).to be_present

    get expected_next_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("matching-run-050")
    expect(response.body).not_to include("completed-run")
    expect(response.body).to include("予定時刻: #{scheduled_from} から #{scheduled_to} まで")
  end

  it "bounds invalid run history page and oversized per_page values" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "bounded_history_job", last_status: "completed")
    120.times do |index|
      create_run!(schedule, status: "completed", active_job_id: format("bounded-run-%03d", index), scheduled_at: index.minutes.ago)
    end

    get admin_recurring_job_schedule_path(schedule, page: "invalid", per_page: "999")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("bounded-run-000")
    expect(response.body).to include("bounded-run-099")
    expect(response.body).not_to include("bounded-run-100")
    expect(response.body).to include("表示中: 1-100件 / 全120件（100件ずつ、1/2ページ）")
    expect(parsed_html.at_css(%(select[name="per_page"] option[value="100"][selected]))).to be_present
  end

  it "masks detail diagnostics while preserving operational context" do
    sign_in_as(admin_user)
    schedule = create_schedule!(
      job_key: "masked_detail_job",
      job_class: "MaskedDetailJob",
      queue_name: "critical",
      last_status: "failed",
      last_error_message: "Authorization: Bearer last-error-token-1968 failed token=last-secret-1968 at /Users/alice/jobs/source.yml",
      args_json: [
        {
          "job_id" => "visible-job-id-1968",
          "authorization" => "Bearer arg-secret-1968",
          "nested" => {
            "client_secret" => "client-secret-1968",
            "source_path" => "/home/alice/source.csv",
            "note" => "retry current project"
          }
        }
      ]
    )
    create_run!(
      schedule,
      status: "failed",
      active_job_id: "active-job-1968",
      error_message: "password=run-secret-1968 while reading C:/Users/alice/tmp.log"
    )

    get admin_recurring_job_schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("masked_detail_job")
    expect(response.body).to include("MaskedDetailJob")
    expect(response.body).to include("critical")
    expect(response.body).to include("visible-job-id-1968")
    expect(response.body).to include("retry current project")
    expect(response.body).to include("active-job-1968")
    expect(response.body).to include("[FILTERED]")
    expect(response.body).not_to include("last-error-token-1968")
    expect(response.body).not_to include("last-secret-1968")
    expect(response.body).not_to include("arg-secret-1968")
    expect(response.body).not_to include("client-secret-1968")
    expect(response.body).not_to include("run-secret-1968")
    expect(response.body).not_to include("/Users/alice/jobs/source.yml")
    expect(response.body).not_to include("/home/alice/source.csv")
    expect(response.body).not_to include("C:/Users/alice/tmp.log")
  end

  it "filters recent runs on the detail page without changing the request action" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "history_job", last_status: "failed")
    create_run!(schedule, status: "completed", active_job_id: "completed-run")
    create_run!(schedule, status: "failed", active_job_id: "failed-run", error_message: "boom")
    allow(RecurringJobDispatcherJob).to receive(:perform_later)

    get admin_recurring_job_schedule_path(schedule, run_status: "failed", return_to: admin_recurring_job_schedules_path(status: "failed", enabled: "false"))

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("failed-run")
    expect(response.body).to include("boom")
    expect(response.body).not_to include("completed-run")
    expect(response.body).to include("Triage対象: 失敗: 1件 / 実行中: 0件 / キュー待ち: 0件")

    expect do
      post request_run_admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path(status: "failed", enabled: "false"))
    end.to change { schedule.reload.run_requested_at }.from(nil)

    expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path(status: "failed", enabled: "false")))
    expect(RecurringJobDispatcherJob).to have_received(:perform_later)
  end

  it "filters run history by active job id, error fragments, and status together" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "run_query_job", last_status: "failed")
    create_run!(schedule, status: "failed", active_job_id: "failed-run-match-1967", error_message: "retry timeout")
    create_run!(schedule, status: "failed", active_job_id: "failed-run-other-1967", error_message: "other failure")
    create_run!(schedule, status: "completed", active_job_id: "completed-run-match-1967", error_message: "retry timeout")

    get admin_recurring_job_schedule_path(schedule, run_status: "failed", q: "MATCH-1967", return_to: admin_recurring_job_schedules_path(status: "failed"))

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("failed-run-match-1967")
    expect(response.body).not_to include("completed-run-match-1967")
    expect(response.body).not_to include("failed-run-other-1967")
    expect(parsed_html.at_css(%(select[name="run_status"] option[value="failed"][selected]))).to be_present
    expect(parsed_html.at_css(%(input[name="q"][value="MATCH-1967"]))).to be_present
    expect(response.body).to include("検索対象: ActiveJob ID またはエラー断片（MATCH-1967）")
    expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path(status: "failed"))}"]))).to be_present

    get admin_recurring_job_schedule_path(schedule, q: "timeout")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("failed-run-match-1967", "completed-run-match-1967")
    expect(response.body).not_to include("failed-run-other-1967")
  end

  it "shows and preserves the run history search boundary" do
    sign_in_as(admin_user)
    bounded_fragment = "a" * Admin::RecurringJobSchedulesController::RUN_QUERY_MAX_LENGTH
    long_fragment = "  #{bounded_fragment}extra-error-log-tail  "
    schedule = create_schedule!(job_key: "bounded_run_query_job", last_status: "failed")
    list_path = admin_recurring_job_schedules_path(status: "failed")
    51.times do |index|
      create_run!(schedule, status: "failed", active_job_id: format("bounded-query-run-%03d", index), error_message: bounded_fragment, scheduled_at: index.minutes.ago)
    end
    create_run!(schedule, status: "failed", active_job_id: "tail-only-run", error_message: "extra-error-log-tail")

    get admin_recurring_job_schedule_path(schedule, run_status: "failed", q: long_fragment, return_to: list_path)

    expect(response).to have_http_status(:ok)
    search_input = parsed_html.at_css(%(input[name="q"]))
    expect(search_input).to be_present
    expect(search_input["maxlength"]).to eq(Admin::RecurringJobSchedulesController::RUN_QUERY_MAX_LENGTH.to_s)
    expect(search_input["value"]).to eq(bounded_fragment)
    expect(response.body).to include("実行履歴検索はActiveJob ID / エラー断片を最大#{Admin::RecurringJobSchedulesController::RUN_QUERY_MAX_LENGTH}文字で指定できます。")
    expect(response.body).to include("検索対象: ActiveJob ID またはエラー断片（#{bounded_fragment}）")
    expect(response.body).to include("bounded-query-run-000")
    expect(response.body).not_to include("tail-only-run")

    expected_next_path = admin_recurring_job_schedule_path(
      schedule,
      return_to: list_path,
      run_status: "failed",
      q: bounded_fragment,
      per_page: 50,
      page: 2
    )
    expect(parsed_html.at_css(%(a[href="#{expected_next_path}"]))).to be_present
  end

  it "shows an empty state and treats blank run search as no condition on the detail page" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "blank_run_query_job", last_status: "completed")
    create_run!(schedule, status: "completed", active_job_id: "completed-run")
    create_run!(schedule, status: "failed", active_job_id: "failed-run", error_message: "boom")

    get admin_recurring_job_schedule_path(schedule, q: "missing-run")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("表示中: 0-0件 / 全0件（50件ずつ、1/1ページ）")
    expect(response.body).to include("条件に一致する実行履歴はありません。")
    expect(parsed_html.at_css(%(input[name="q"][value="missing-run"]))).to be_present

    get admin_recurring_job_schedule_path(schedule, q: "   ")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("completed-run", "failed-run")
    expect(response.body).not_to include("条件に一致する実行履歴はありません。")
  end

  it "ignores invalid run status filters on the detail page" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "invalid_run_filter_job", last_status: "failed")
    create_run!(schedule, status: "completed", active_job_id: "completed-run")
    create_run!(schedule, status: "failed", active_job_id: "failed-run")

    get admin_recurring_job_schedule_path(schedule, run_status: "archived", q: "run")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("completed-run")
    expect(response.body).to include("failed-run")
    expect(parsed_html.at_css(%(select[name="run_status"] option[value="archived"][selected]))).to be_blank
  end

  it "keeps safe return_to values on the detail page and request action" do
    sign_in_as(admin_user)
    schedule = create_schedule!
    return_to = admin_recurring_job_schedules_path(status: "failed", enabled: "false")
    allow(RecurringJobDispatcherJob).to receive(:perform_later)

    get admin_recurring_job_schedule_path(schedule, return_to:)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(a[href="#{return_to}"]))).to be_present

    post request_run_admin_recurring_job_schedule_path(schedule, return_to:)

    expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to:))
    expect(RecurringJobDispatcherJob).to have_received(:perform_later)
  end

  it "falls back to the list path for protocol-relative return_to values" do
    sign_in_as(admin_user)
    schedule = create_schedule!
    invalid_return_to = "//example.com"
    allow(RecurringJobDispatcherJob).to receive(:perform_later)

    get admin_recurring_job_schedule_path(schedule, return_to: invalid_return_to)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedules_path}"]))).to be_present

    post request_run_admin_recurring_job_schedule_path(schedule, return_to: invalid_return_to)

    expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path))
    expect(RecurringJobDispatcherJob).to have_received(:perform_later)
  end

  def listed_schedule_keys
    parsed_html.css("tbody tr td:first-child a").map { |node| node.text.squish }
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

  def create_run!(schedule, attributes = {})
    defaults = {
      recurring_job_schedule: schedule,
      job_key: schedule.job_key,
      job_class: schedule.job_class,
      queue_name: schedule.queue_name,
      status: "enqueued",
      scheduled_at: Time.current,
      args_json: []
    }

    RecurringJobRun.create!(defaults.merge(attributes))
  end
end
