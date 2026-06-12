require "rails_helper"

RSpec.describe "Admin dashboard generated file failure candidate links", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def action_targets
    parsed_html.css("a[href]").map { |node| node["href"] }
  end

  it "links each consecutive failure candidate to failed runs filtered by identity" do
    latest_failure_at = 30.minutes.ago.change(usec: 0)
    [latest_failure_at, 45.minutes.ago, 1.hour.ago].each do |started_at|
      GeneratedFileRun.create!(
        job_id: "docs-build",
        generator: "docusaurus",
        output_writer: nil,
        event_source: "schedule",
        status: :failed,
        started_at: started_at,
        finished_at: started_at + 1.minute,
        error_message: "latest docusaurus timeout"
      )
    end

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(
      admin_generated_file_runs_path(
        status: "failed",
        job_id: "docs-build",
        generator: "docusaurus",
        event_source: "schedule"
      )
    )
    expect(action_targets).to include(admin_generated_file_runs_path(status: "failed"))
    expect(action_targets.join("\n")).not_to include("output_writer=")
    expect(parsed_html.text.squish).to include("この候補の failed 実行履歴")
  end
end
