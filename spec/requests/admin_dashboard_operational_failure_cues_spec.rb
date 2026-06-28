require "rails_helper"

RSpec.describe "Admin dashboard operational failure cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  before do
    sign_in_as(admin_user)
  end

  it "separates saved failure counts from generated file alert candidates" do
    GeneratedFileRun.create!(job_id: "docs-build", status: :failed)
    alert_candidate_service = instance_double(GeneratedFiles::RunFailureAlertCandidates, call: [])
    allow(GeneratedFiles::RunFailureAlertCandidates).to receive(:new).and_return(alert_candidate_service)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("保存済み履歴の件数です。継続失敗候補や通知状態とは別に確認します。")
    expect(page_text).to include("継続失敗候補: 0 件")
    expect(page_text).to include("候補 0 件は正常保証ではありません。")
    expect(page_text).to include("保存済み failed 件数が 0 件であることや正常状態を保証する表示ではありません。")
    expect(page_text).to include("実行履歴 failed: 1")
  end

  it "keeps generated file alert candidate investigation links readable" do
    latest_failure_at = 30.minutes.ago.change(usec: 0)
    [latest_failure_at, 45.minutes.ago, 1.hour.ago].each do |started_at|
      GeneratedFileRun.create!(
        job_id: "docs-build",
        generator: "docusaurus",
        output_writer: "filesystem",
        event_source: "schedule",
        status: :failed,
        started_at: started_at,
        finished_at: started_at + 1.minute,
        error_message: "docusaurus timeout"
      )
    end

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("継続失敗候補: 1 件")
    expect(page_text).to include("保存済み failed 件数とは別の read-only 調査入口です。")
    expect(page_text).to include("docs-build")
    expect(page_text).to include("docusaurus / filesystem / schedule")
    expect(page_text).to include("連続失敗: 3 件")
    expect(page_text).to include("この候補の failed 実行履歴")
  end

  it "shows external folder sync failure handoff candidates without leaking sensitive values" do
    project = create(:project, code: "SYNCOPS", name: "Sync Operations")
    source = ExternalFolderSyncSource.create!(
      project: project,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive source",
      folder_url: "https://drive.google.com/drive/folders/spec-folder",
      external_folder_id: "spec-folder",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      auth_config: "{}",
      enabled: true
    )
    latest_failure_at = 20.minutes.ago.change(usec: 0)
    [latest_failure_at, 40.minutes.ago, 1.hour.ago].each_with_index do |started_at, index|
      ExternalFolderSyncRun.create!(
        external_folder_sync_source: source,
        status: index.zero? ? :partial : :failed,
        mode: :dry_run,
        started_at: started_at,
        finished_at: started_at + 1.minute,
        error_message: index.zero? ? "Authorization: Bearer raw-token token=secret /home/app/private" : "older failure"
      )
    end

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("外部フォルダ同期")
    expect(page_text).to include("failed: 2")
    expect(page_text).to include("partial: 1")
    expect(page_text).to include("外部フォルダ同期 source ごとに、最新 run から failed / partial が連続しているものだけを read-only に表示します。")
    expect(page_text).to include("Drive source")
    expect(page_text).to include("google_drive / SYNCOPS Sync Operations")
    expect(page_text).to include("連続 failed / partial: 3 件")
    expect(response.body).to include(I18n.l(latest_failure_at + 1.minute, format: :short))
    expect(page_text).to include("Authorization: Bearer [FILTERED]")
    expect(page_text).to include("token=[FILTERED]")
    expect(page_text).to include("[path omitted]")
    expect(page_text).to include("この候補の同期設定")
    expect(response.body).to include("/admin/external_folder_sync_sources/#{source.to_param}")
    expect(page_text).not_to include("raw-token")
    expect(page_text).not_to include("token=secret")
    expect(page_text).not_to include("/home/app/private")
  end
end
