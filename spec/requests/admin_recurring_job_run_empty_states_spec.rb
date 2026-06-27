require "rails_helper"

RSpec.describe "Admin recurring job run empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows the not-yet-run message when no run history exists" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "no_history_job", last_status: nil)

    get admin_recurring_job_schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("表示中: 0-0件 / 全0件（50件ずつ、1/1ページ）")
    expect(response.body).to include("まだ実行履歴はありません。即時実行要求または次回 dispatcher enqueue 後に、結果がここへ50件ずつ表示されます。")
    expect(response.body).not_to include("条件に一致する実行履歴はありません。")
  end

  it "shows the filter mismatch message with reset guidance when run filters match no rows" do
    sign_in_as(admin_user)
    schedule = create_schedule!(job_key: "filtered_history_job", last_status: "completed")
    create_run!(schedule, status: "completed", active_job_id: "completed-run-2355")

    get admin_recurring_job_schedule_path(schedule, run_status: "failed", q: "missing-run")

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("表示中: 0-0件 / 全0件（50件ずつ、1/1ページ）")
    expect(response.body).to include("条件に一致する実行履歴はありません。")
    expect(response.body).to include("状態や検索語を見直すか、絞り込み解除で履歴の先頭ページに戻してください。")
    expect(response.body).to include("検索対象: ActiveJob ID またはエラー断片（missing-run）")
    expect(response.body).to include("絞り込み解除")
    expect(response.body).not_to include("completed-run-2355")
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
