require "rails_helper"

RSpec.describe "Admin generated file run failure alert handoff", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_body
    JSON.parse(response.body)
  end

  describe "GET /admin/generated_file_runs/failure_alert_handoff" do
    it "shows read-only handoff entries for internal admins without raw sensitive error details" do
      latest_failure_at = Time.zone.parse("2026-06-13 10:00:00")
      create_run!(
        status: :failed,
        started_at: latest_failure_at,
        error_message: "Authorization: Bearer super-secret-token token=raw-secret failed at /home/app/private/build.log"
      )
      create_run!(status: :failed, started_at: latest_failure_at - 5.minutes, error_message: "older failure")
      create_run!(status: :failed, started_at: latest_failure_at - 10.minutes, error_message: "oldest failure")

      sign_in_as(admin_user)

      get failure_alert_handoff_admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("生成ファイル継続失敗候補 handoff")
      expect(page_text).to include("read-only")
      expect(page_text).to include("通知送信、ack、再通知抑制、自動 retry")
      expect(page_text).to include("候補 1")
      expect(page_text).to include("docs-build")
      expect(page_text).to include("job_id=docs-build / generator=docusaurus / output_writer=filesystem / event_source=schedule")
      expect(page_text).to include("連続失敗: 3 件")
      expect(page_text).to include("[FILTERED]")
      expect(page_text).to include("[path omitted]")
      expect(page_text).to include("docs/生成ファイル継続失敗候補runbook.md")
      expect(response.body).to include("/admin/generated_file_runs?event_source=schedule&amp;generator=docusaurus&amp;job_id=docs-build&amp;output_writer=filesystem&amp;status=failed")
      expect(response.body).not_to include("super-secret-token")
      expect(response.body).not_to include("raw-secret")
      expect(response.body).not_to include("/home/app/private")
    end

    it "shows an explicit empty-state without treating zero candidates as healthy or acknowledged" do
      handoff_service = instance_double(GeneratedFiles::RunFailureAlertHandoff, call: [])
      expect(GeneratedFiles::RunFailureAlertHandoff).to receive(:new).with(
        limit: Admin::GeneratedFileRunsController::FAILURE_ALERT_HANDOFF_LIMIT,
        lookback_limit: Admin::GeneratedFileRunsController::FAILURE_ALERT_HANDOFF_LOOKBACK_LIMIT
      ).and_return(handoff_service)

      sign_in_as(admin_user)

      get failure_alert_handoff_admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("継続失敗候補はありません。")
      expect(page_text).to include("正常であること、通知済み・ack済み・自動 retry 済みであることは示しません。")
    end

    it "returns a JSON handoff payload with candidate links and non-goals" do
      create_run!(status: :failed, started_at: 1.hour.ago, error_message: "latest timeout")
      create_run!(status: :failed, started_at: 2.hours.ago, error_message: "older timeout")
      create_run!(status: :failed, started_at: 3.hours.ago, error_message: "oldest timeout")

      sign_in_as(admin_user)

      get failure_alert_handoff_admin_generated_file_runs_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
      expect(json_body).to include(
        "count" => 1,
        "failed_runs_path" => "/admin/generated_file_runs?status=failed",
        "runbook_path" => "docs/生成ファイル継続失敗候補runbook.md",
        "read_only" => true,
        "non_goals" => %w[notification ack escalation retry]
      )
      expect(json_body.fetch("candidates").first).to include(
        "failure_count" => 3,
        "latest_error_message" => "latest timeout",
        "failed_runs_path" => "/admin/generated_file_runs?status=failed",
        "runbook_path" => "docs/生成ファイル継続失敗候補runbook.md"
      )
      expect(json_body.dig("candidates", 0, "identity")).to include(
        "job_id" => "docs-build",
        "generator" => "docusaurus",
        "output_writer" => "filesystem",
        "event_source" => "schedule"
      )
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get failure_alert_handoff_admin_generated_file_runs_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  def create_run!(attributes = {})
    defaults = {
      job_id: "docs-build",
      generator: "docusaurus",
      output_writer: "filesystem",
      event_source: "schedule",
      status: :failed,
      source_paths: ["docs/source.yml"],
      changed_files: ["docs/source.yml"],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.hour.ago,
      finished_at: Time.current
    }
    GeneratedFileRun.create!(defaults.merge(attributes))
  end
end
