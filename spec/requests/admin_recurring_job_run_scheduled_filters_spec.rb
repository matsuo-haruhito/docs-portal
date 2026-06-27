require "rails_helper"

RSpec.describe "Admin recurring job run scheduled filters", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "filters run history by scheduled date range within the current schedule" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "scheduled_range_job")
    other_schedule = create_schedule!(job_key: "other_scheduled_range_job")

    create_run!(schedule, active_job_id: "before-range", scheduled_at: Time.zone.parse("2026-01-09 23:59:59"))
    create_run!(schedule, active_job_id: "inside-start", scheduled_at: Time.zone.parse("2026-01-10 00:00:00"))
    create_run!(schedule, active_job_id: "inside-end", scheduled_at: Time.zone.parse("2026-01-10 23:59:59"))
    create_run!(schedule, active_job_id: "after-range", scheduled_at: Time.zone.parse("2026-01-11 00:00:00"))
    create_run!(other_schedule, active_job_id: "other-schedule-inside", scheduled_at: Time.zone.parse("2026-01-10 12:00:00"))

    get admin_recurring_job_schedule_path(schedule, scheduled_from: "2026-01-10", scheduled_to: "2026-01-10")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("inside-start", "inside-end")
    expect(response.body).not_to include("before-range")
    expect(response.body).not_to include("after-range")
    expect(response.body).not_to include("other-schedule-inside")
    expect(parsed_html.at_css(%(input[name="scheduled_from"][value="2026-01-10"]))).to be_present
    expect(parsed_html.at_css(%(input[name="scheduled_to"][value="2026-01-10"]))).to be_present
    expect(response.body).to include("予定時刻: 2026-01-10 から 2026-01-10 まで")
    expect(response.body).to include("表示中: 1-2件 / 全2件（50件ずつ、1/1ページ）")
  end

  it "combines status, query, and scheduled time filters" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "combined_scheduled_filter_job")

    create_run!(
      schedule,
      status: "failed",
      active_job_id: "target-match-2357",
      error_message: "retry MATCH-2357 timeout",
      scheduled_at: Time.zone.parse("2026-02-03 12:00:00")
    )
    create_run!(
      schedule,
      status: "failed",
      active_job_id: "wrong-query-2357",
      error_message: "other failure",
      scheduled_at: Time.zone.parse("2026-02-03 13:00:00")
    )
    create_run!(
      schedule,
      status: "completed",
      active_job_id: "wrong-status-2357",
      error_message: "MATCH-2357 completed",
      scheduled_at: Time.zone.parse("2026-02-03 14:00:00")
    )
    create_run!(
      schedule,
      status: "failed",
      active_job_id: "wrong-time-2357",
      error_message: "MATCH-2357 outside",
      scheduled_at: Time.zone.parse("2026-02-04 12:00:00")
    )

    get admin_recurring_job_schedule_path(
      schedule,
      run_status: "failed",
      q: "match-2357",
      scheduled_from: "2026-02-03 09:00",
      scheduled_to: "2026-02-03 18:00"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("target-match-2357")
    expect(response.body).not_to include("wrong-query-2357")
    expect(response.body).not_to include("wrong-status-2357")
    expect(response.body).not_to include("wrong-time-2357")
    expect(parsed_html.at_css(%(select[name="run_status"] option[value="failed"][selected]))).to be_present
    expect(parsed_html.at_css(%(input[name="q"][value="match-2357"]))).to be_present
    expect(parsed_html.at_css(%(input[name="scheduled_from"][value="2026-02-03 09:00"]))).to be_present
    expect(parsed_html.at_css(%(input[name="scheduled_to"][value="2026-02-03 18:00"]))).to be_present
  end

  it "ignores only invalid scheduled time filters and shows a warning" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "invalid_scheduled_filter_job")

    create_run!(schedule, active_job_id: "before-valid-to", scheduled_at: Time.zone.parse("2026-03-05 10:00:00"))
    create_run!(schedule, active_job_id: "after-valid-to", scheduled_at: Time.zone.parse("2026-03-06 10:00:00"))

    get admin_recurring_job_schedule_path(schedule, scheduled_from: "not-a-date", scheduled_to: "2026-03-05")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("before-valid-to")
    expect(response.body).not_to include("after-valid-to")
    expect(response.body).to include("予定時刻(開始)「not-a-date」は日時として解釈できないため、この条件は適用していません。")
    expect(parsed_html.at_css(%(input[name="scheduled_from"][value="not-a-date"]))).to be_present
    expect(parsed_html.at_css(%(input[name="scheduled_to"][value="2026-03-05"]))).to be_present
  end

  it "shows the filtered empty state and reset link for scheduled time filters" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "empty_scheduled_filter_job")
    create_run!(schedule, active_job_id: "outside-empty-range", scheduled_at: Time.zone.parse("2026-04-01 10:00:00"))

    get admin_recurring_job_schedule_path(schedule, scheduled_from: "2026-04-02", scheduled_to: "2026-04-02")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("表示中: 0-0件 / 全0件（50件ずつ、1/1ページ）")
    expect(response.body).to include("条件に一致する実行履歴はありません。")
    expect(response.body).to include("状態・検索語・予定時刻を見直すか、絞り込み解除で履歴の先頭ページに戻してください。")
    expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path)}"]))).to be_present
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
