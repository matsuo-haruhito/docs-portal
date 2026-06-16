require "rails_helper"

RSpec.describe "Admin generated file run retry evidence", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def retry_evidence_section
    parsed_html.css("div").find { |node| node.at_css("h2")&.text&.squish == "再実行履歴" }
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows retry metadata as read-only evidence while masking failure details" do
    sign_in_as(admin_user)
    requester = create(:user, :internal, name: "Retry Operator", email_address: "retry-operator@example.com")
    original_run = create_run!(job_id: "docusaurus_site_build", status: :failed)
    retry_run = create_run!(
      job_id: "docusaurus_site_build",
      status: :failed,
      event_source: "generated_file_run_bulk_retry",
      error_message: "Authorization: Bearer raw-token token=raw-secret failed at /workspace/docs-portal/tmp/build.log",
      metadata: {
        "retry_of_generated_file_run_public_id" => original_run.public_id,
        "retry_requested_at" => "2026-06-16T09:30:00Z",
        "retry_requested_by_user_id" => requester.id,
        "bulk_retry" => true
      }
    )

    get admin_generated_file_run_path(retry_run.public_id)

    expect(response).to have_http_status(:ok)
    section = retry_evidence_section
    expect(section).to be_present
    expect(section.text.squish).to include(
      "一括再実行",
      original_run.public_id,
      "Retry Operator (retry-operator@example.com)",
      "2026-06-16T09:30:00Z",
      retry_run.public_id,
      "docs/生成ファイル再試行と定期ジョブ管理runbook.md"
    )
    expect(section.at_css(%(a[href="#{admin_generated_file_run_path(original_run.public_id)}"]))).to be_present
    expect(page_text).to include("[FILTERED]")
    expect(response.body).not_to include("raw-token", "raw-secret", "/workspace/docs-portal")
  end

  it "shows fallback markers for retry-like runs with missing metadata" do
    sign_in_as(admin_user)
    run = create_run!(
      job_id: "manual_regeneration",
      status: :completed,
      event_source: "generated_file_run_retry",
      metadata: {}
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    section_text = retry_evidence_section.text.squish
    expect(section_text).to include("再実行履歴", "再実行")
    expect(section_text).to include("再実行元 -")
    expect(section_text).to include("再実行依頼者 -")
    expect(section_text).to include("再実行依頼時刻 -")
    expect(section_text).to include("docs/生成ファイル再試行と定期ジョブ管理runbook.md")
  end

  def create_run!(attributes = {})
    defaults = {
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :completed,
      event_source: "spec",
      source_paths: ["source.yml"],
      changed_files: ["source.yml"],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    }
    GeneratedFileRun.create!(defaults.merge(attributes))
  end
end
