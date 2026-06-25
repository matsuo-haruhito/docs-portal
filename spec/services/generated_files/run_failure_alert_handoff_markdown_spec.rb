require "rails_helper"

RSpec.describe "Generated file run failure alert handoff markdown" do
  it "renders a read-only markdown digest with filtered failed run paths" do
    latest_failure = create_run(
      status: :failed,
      output_writer: nil,
      error_message: "first line\nsecond line",
      started_at: 1.hour.ago
    )

    entries = GeneratedFiles::RunFailureAlertHandoff.new(threshold: 1).call
    markdown = GeneratedFiles::RunFailureAlertHandoff.markdown(entries)

    expect(markdown).to include("## 生成ファイル継続失敗候補 digest")
    expect(markdown).to include("通知・ack・SLA・自動 retry の状態ではない read-only preview")
    expect(markdown).to include("identity: job_id=docs-build / generator=docusaurus / event_source=schedule")
    expect(markdown).to include("consecutive_failures: 1")
    expect(markdown).to include("last_failed_at: #{latest_failure.finished_at.iso8601}")
    expect(markdown).to include("error_preview: first line second line")
    expect(markdown).to include("failed_runs_path: /admin/generated_file_runs?")
    expect(markdown).to include("status=failed")
    expect(markdown).to include("job_id=docs-build")
    expect(markdown).to include("generator=docusaurus")
    expect(markdown).to include("event_source=schedule")
    expect(markdown).not_to include("output_writer=")
    expect(markdown).to include("runbook_path: docs/生成ファイル継続失敗候補runbook.md")
  end

  it "renders a safe zero-candidate digest without implying normal operation" do
    markdown = GeneratedFiles::RunFailureAlertHandoff.markdown([])

    expect(markdown).to include("候補 0 件です")
    expect(markdown).to include("正常保証")
    expect(markdown).to include("通知済み")
    expect(markdown).to include("自動 retry 済みを意味しません")
  end

  it "does not expose raw token-like values or private paths in the digest" do
    create_run(
      status: :failed,
      error_message: "token=raw-secret failed at /var/private/generated/output.json",
      started_at: 1.hour.ago
    )

    entries = GeneratedFiles::RunFailureAlertHandoff.new(threshold: 1).call
    markdown = GeneratedFiles::RunFailureAlertHandoff.markdown(entries)

    expect(markdown).to include("token=[FILTERED]")
    expect(markdown).to include("[path omitted]")
    expect(markdown).not_to include("raw-secret")
    expect(markdown).not_to include("/var/private/generated/output.json")
  end

  def create_run(status:, job_id: "docs-build", generator: "docusaurus", output_writer: "filesystem", event_source: "schedule", started_at:, error_message: "boom")
    create(
      :generated_file_run,
      status: status,
      job_id: job_id,
      generator: generator,
      output_writer: output_writer,
      event_source: event_source,
      started_at: started_at,
      finished_at: started_at + 1.minute,
      error_message: status.to_sym == :failed ? error_message : nil
    )
  end
end
