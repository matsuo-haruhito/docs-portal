require "rails_helper"

RSpec.describe "Admin recurring job schedule Git import empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "guides admins from an unregistered Git import source state to settings" do
    sign_in_as(admin_user)
    schedule = create_schedule!

    get admin_recurring_job_schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Git連携元はまだ登録されていません。")
    expect(response.body).to include("で同期元を登録すると、この画面で有効件数と対象状態を確認できます。")
    expect(parsed_html.at_css(%(a[href="#{admin_git_import_sources_path}"]))).to be_present
    expect(response.body).to include("Git同期履歴はまだありません。Git連携元の登録・有効化後に同期が実行されると、結果を")
    expect(parsed_html.at_css(%(a[href="#{admin_git_import_runs_path}"]))).to be_present
  end

  it "clarifies when registered Git import sources are all disabled" do
    sign_in_as(admin_user)
    schedule = create_schedule!
    create_git_import_source!(enabled: false)

    get admin_recurring_job_schedule_path(schedule)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("有効 0件 / 全 1件")
    expect(response.body).to include("登録済みのGit連携元はありますが、有効な設定がありません。Git連携設定で利用する同期元を有効化してください。")
    expect(response.body).to include("Git同期履歴はまだありません。Git連携元の登録・有効化後に同期が実行されると、結果を")
    expect(parsed_html.at_css(%(a[href="#{admin_git_import_sources_path}"]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{admin_git_import_runs_path}"]))).to be_present
  end

  def create_schedule!
    RecurringJobSchedule.create!(
      job_key: "sync_git_import_sources",
      job_class: "SyncGitImportSourcesJob",
      queue_name: "default",
      interval_seconds: 1.hour.to_i,
      next_run_at: 1.hour.from_now,
      enabled: true,
      allow_overlap: false,
      args_json: []
    )
  end

  def create_git_import_source!(attributes = {})
    GitImportSource.create!(
      {
        project: create(:project),
        created_by: admin_user,
        repository_full_name: "matsuo-haruhito/docs-portal",
        branch: "main",
        source_path: "docs",
        provider: :github,
        auth_type: :no_auth,
        enabled: true
      }.merge(attributes)
    )
  end
end
