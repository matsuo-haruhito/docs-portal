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
end
