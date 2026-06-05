require "rails_helper"

RSpec.describe "Admin recurring job schedule action grouping", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "separates the immediate request action from navigation and shows execution context" do
    sign_in_as(admin_user)
    schedule = create_schedule!(
      job_key: "request_grouping_job",
      job_class: "RequestGroupingJob",
      queue_name: "critical",
      allow_overlap: false,
      last_status: "failed",
      run_requested_at: 10.minutes.ago
    )
    create_run!(schedule, status: "failed", active_job_id: "failed-run-2119")
    return_to = admin_recurring_job_schedules_path(status: "failed", enabled: "true")

    get admin_recurring_job_schedule_path(schedule, return_to:)

    expect(response).to have_http_status(:ok)
    action_card = parsed_html.css(".card").find { |card| card.at_css("h2")&.text&.squish == "即時実行要求" }

    expect(action_card).to be_present
    action_context = definition_values(action_card)

    expect(action_card.text.squish).to include("実行系 action")
    expect(action_context).to include(
      "対象 job key" => "request_grouping_job",
      "キュー" => "critical",
      "重複実行" => "禁止",
      "前回状態" => "失敗"
    )
    expect(action_context.fetch("要求状況")).to include("要求済み")
    expect(action_card.text.squish).to include("結果は下の実行履歴で確認してください")
    expect(action_card.at_css(%(a[href="#{request_run_admin_recurring_job_schedule_path(schedule, return_to:)}"]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{return_to}"])).text.squish).to eq("一覧へ戻る")
    expect(response.body).to include("failed-run-2119")
    expect(response.body).to include("表示中: 1件（最新50件まで）")
  end

  def definition_values(card)
    labels = card.css("dt").map { |node| node.text.squish }
    values = card.css("dd").map { |node| node.text.squish }

    labels.zip(values).to_h
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
