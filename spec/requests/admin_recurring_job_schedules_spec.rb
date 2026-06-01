require "rails_helper"

RSpec.describe "Admin recurring job schedules", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "filters schedules by previous status while keeping the sync action available" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "failed_job", last_status: "failed")
    create_schedule!(job_key: "completed_job", last_status: "completed")
    create_schedule!(job_key: "not_run_job", last_status: nil)

    get admin_recurring_job_schedules_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["failed_job"])
    expect(parsed_html.at_css(%(a[href="#{admin_recurring_job_schedules_path(sync_definitions: 1)}"]))).to be_present
    expect(response.body).to include("Triage対象: 失敗: 1件 / 実行中: 0件 / キュー待ち: 0件")
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

  it "filters schedules with no previous run status" do
    sign_in_as(admin_user)
    create_schedule!(job_key: "failed_job", last_status: "failed")
    create_schedule!(job_key: "not_run_job", last_status: nil)

    get admin_recurring_job_schedules_path(status: "not_run")

    expect(response).to have_http_status(:ok)
    expect(listed_schedule_keys).to eq(["not_run_job"])
  end

  it "limits recent runs on the detail page to the latest 50 entries" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "history_limit_job", last_status: "completed")
    create_run!(schedule, status: "completed", active_job_id: "oldest-run", scheduled_at: 2.days.ago)
    50.times do |index|
      create_run!(schedule, status: "completed", active_job_id: "recent-run-#{index}", scheduled_at: index.minutes.ago)
    end

    get admin_recurring_job_schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("recent-run-0")
    expect(response.body).to include("recent-run-49")
    expect(response.body).not_to include("oldest-run")
  end

  it "filters recent runs on the detail page without changing the request action" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "history_job", last_status: "failed")
    create_run!(schedule, status: "completed", active_job_id: "completed-run")
    create_run!(schedule, status: "failed", active_job_id: "failed-run", error_message: "boom")
    allow(RecurringJobDispatcherJob).to receive(:perform_later)

    get admin_recurring_job_schedule_path(schedule, run_status: "failed", return_to: admin_recurring_job_schedules_path(status: "failed"))

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("failed-run")
    expect(response.body).to include("boom")
    expect(response.body).not_to include("completed-run")
    expect(response.body).to include("Triage対象: 失敗: 1件 / 実行中: 0件 / キュー待ち: 0件")

    expect do
      post request_run_admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path(status: "failed"))
    end.to change { schedule.reload.run_requested_at }.from(nil)

    expect(response).to redirect_to(admin_recurring_job_schedule_path(schedule, return_to: admin_recurring_job_schedules_path(status: "failed")))
    expect(RecurringJobDispatcherJob).to have_received(:perform_later)
  end

  it "ignores invalid run status filters on the detail page" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "invalid_run_filter_job", last_status: "failed")
    create_run!(schedule, status: "completed", active_job_id: "completed-run")
    create_run!(schedule, status: "failed", active_job_id: "failed-run")

    get admin_recurring_job_schedule_path(schedule, run_status: "archived")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("completed-run")
    expect(response.body).to include("failed-run")
  end

  it "keeps safe return_to values on the detail page and request action" do
    sign_in_as(admin_user)
    schedule = create_schedule!
    return_to = admin_recurring_job_schedules_path(status: "failed")
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
