require "rails_helper"

RSpec.describe "Admin recurring job schedules", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_schedule(job_key:, last_status:, enabled: true)
    RecurringJobSchedule.create!(
      job_key: job_key,
      job_class: "RecurringExampleJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      enabled: enabled,
      last_status: last_status,
      args_json: {}
    )
  end

  def create_run(schedule, status:, scheduled_at:, error_message: nil)
    schedule.recurring_job_runs.create!(
      job_key: schedule.job_key,
      job_class: schedule.job_class,
      queue_name: schedule.queue_name,
      status: status,
      scheduled_at: scheduled_at,
      error_message: error_message
    )
  end

  it "filters schedules by last status and shows triage counts" do
    failed_schedule = create_schedule(job_key: "generated-file-dispatch", last_status: "failed")
    create_schedule(job_key: "generated-file-buffer", last_status: "running")
    create_schedule(job_key: "nightly-site-build", last_status: "enqueued")

    sign_in_as(admin_user)

    get admin_recurring_job_schedules_path, params: { status: "failed" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("状態: 失敗")
    expect(page_text).to include("失敗: 1件")
    expect(page_text).to include("実行中: 1件")
    expect(page_text).to include("投入済み: 1件")
    expect(page_text).to include(failed_schedule.job_key)
    expect(page_text).not_to include("generated-file-buffer")
    expect(page_text).not_to include("nightly-site-build")

    filter_form = parsed_html.at_css("form[action='#{admin_recurring_job_schedules_path}']")
    expect(filter_form).to be_present
    expect(filter_form.at_css("select[name='status']")).to be_present
  end

  it "filters run history by execution status and keeps the schedule summary visible" do
    schedule = create_schedule(job_key: "generated-file-dispatch", last_status: "failed")
    create_run(schedule, status: :failed, scheduled_at: Time.zone.local(2026, 5, 1, 10, 0, 0), error_message: "boom")
    create_run(schedule, status: :running, scheduled_at: Time.zone.local(2026, 5, 1, 9, 0, 0), error_message: "still working")
    create_run(schedule, status: :completed, scheduled_at: Time.zone.local(2026, 5, 1, 8, 0, 0))

    sign_in_as(admin_user)

    get admin_recurring_job_schedule_path(schedule), params: { status: "failed" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("前回状態")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("状態: 失敗")
    expect(page_text).to include("boom")
    expect(page_text).not_to include("still working")

    filter_form = parsed_html.at_css("form[action='#{admin_recurring_job_schedule_path(schedule)}']")
    expect(filter_form).to be_present
    expect(filter_form.at_css("select[name='status']")).to be_present
  end

  it "keeps the request_run redirect and notice contract" do
    schedule = create_schedule(job_key: "nightly-site-build", last_status: "completed")

    sign_in_as(admin_user)

    post request_run_admin_recurring_job_schedule_path(schedule)

    expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule))
    expect(flash[:notice]).to eq("定期ジョブの即時実行を要求しました。")
    expect(schedule.reload.run_requested_at).to be_present
  end
end
