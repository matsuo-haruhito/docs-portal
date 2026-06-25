require "rails_helper"

RSpec.describe "Admin dashboard generated file failure digest", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows a read-only markdown digest preview for generated file failure candidates" do
    latest_failure_at = 30.minutes.ago.change(usec: 0)
    [latest_failure_at, 45.minutes.ago, 1.hour.ago].each_with_index do |started_at, index|
      GeneratedFileRun.create!(
        job_id: "docs-build",
        generator: "docusaurus",
        output_writer: nil,
        event_source: "schedule",
        status: :failed,
        started_at: started_at,
        finished_at: started_at + 1.minute,
        error_message: index.zero? ? "token=raw-secret failed at /var/private/generated/output.json" : "older failure"
      )
    end

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("Markdown digest preview")
    expect(parsed_html.text.squish).to include("通知済み、ack、SLA、自動 retry の状態としては扱いません")

    digest = parsed_html.at_css("textarea[name='generated_file_failure_digest_markdown']")
    expect(digest["readonly"]).to eq("readonly")
    expect(digest.text).to include("## 生成ファイル継続失敗候補 digest")
    expect(digest.text).to include("identity: job_id=docs-build / generator=docusaurus / event_source=schedule")
    expect(digest.text).to include("consecutive_failures: 3")
    expect(digest.text).to include("failed_runs_path: /admin/generated_file_runs?")
    expect(digest.text).to include("job_id=docs-build")
    expect(digest.text).to include("event_source=schedule")
    expect(digest.text).not_to include("output_writer=")
    expect(digest.text).to include("token=[FILTERED]")
    expect(digest.text).to include("[path omitted]")
    expect(digest.text).not_to include("raw-secret")
    expect(digest.text).not_to include("/var/private/generated/output.json")
  end
end
