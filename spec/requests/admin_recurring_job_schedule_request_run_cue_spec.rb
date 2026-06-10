require "rails_helper"

RSpec.describe "Admin recurring job schedule request run cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "separates the initial request cue from the already-requested re-request cue" do
    sign_in_as(admin_user)
    unrequested_schedule = create_schedule!(job_key: "unrequested_cue_job", allow_overlap: false)

    get admin_recurring_job_schedule_path(unrequested_schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まだ即時実行要求はありません。要求するとこの schedule を dispatcher へ渡し、結果は下の実行履歴で確認できます。")
    expect(response.body).to include("重複実行の許可/禁止は同じ schedule の同時実行可否です。即時実行要求済みかどうかとは別に判定されます。")
    request_link = parsed_html.at_css(%(a[href="#{request_run_admin_recurring_job_schedule_path(unrequested_schedule, return_to: admin_recurring_job_schedules_path)}"]))
    expect(request_link).to be_present
    expect(request_link.text).to include("即時実行を要求")

    requested_at = Time.zone.parse("2026-06-10 09:30:00")
    requested_schedule = create_schedule!(job_key: "requested_cue_job", allow_overlap: true, run_requested_at: requested_at)

    get admin_recurring_job_schedule_path(requested_schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("すでに即時実行を要求済みです")
    expect(response.body).to include("再度要求すると要求時刻を更新し、dispatcher enqueue を再依頼します。")
    expect(response.body).to include("enqueue / 開始 / 終了は下の実行履歴で確認してください。")
    expect(response.body).to include("重複実行の許可/禁止は同じ schedule の同時実行可否です。即時実行要求済みかどうかとは別に判定されます。")
    re_request_link = parsed_html.at_css(%(a[href="#{request_run_admin_recurring_job_schedule_path(requested_schedule, return_to: admin_recurring_job_schedules_path)}"]))
    expect(re_request_link).to be_present
    expect(re_request_link.text).to include("即時実行を再要求")
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
