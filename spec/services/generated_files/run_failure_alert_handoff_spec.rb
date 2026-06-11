require "rails_helper"

RSpec.describe GeneratedFiles::RunFailureAlertHandoff do
  describe "#call" do
    it "returns handoff payload entries for consecutive failure candidates" do
      failures = [
        create_run(status: :failed, error_message: "third failure", started_at: 1.hour.ago),
        create_run(status: :failed, error_message: "second failure", started_at: 2.hours.ago),
        create_run(status: :failed, error_message: "first failure", started_at: 3.hours.ago)
      ]

      entries = described_class.new.call

      expect(entries.size).to eq(1)
      entry = entries.first
      expect(entry.job_id).to eq("docs-build")
      expect(entry.generator).to eq("docusaurus")
      expect(entry.output_writer).to eq("filesystem")
      expect(entry.event_source).to eq("schedule")
      expect(entry.failure_count).to eq(3)
      expect(entry.last_failed_at.to_i).to eq(failures.first.finished_at.to_i)
      expect(entry.latest_error_message).to eq("third failure")
      expect(entry.failed_runs_path).to eq("/admin/generated_file_runs?status=failed")
      expect(entry.runbook_path).to eq("docs/生成ファイル継続失敗候補runbook.md")
      expect(entry.to_h).to include(
        identity: {
          job_id: "docs-build",
          generator: "docusaurus",
          output_writer: "filesystem",
          event_source: "schedule"
        },
        failure_count: 3,
        latest_error_message: "third failure"
      )
    end

    it "returns an empty payload when there are no candidates" do
      create_run(status: :completed, started_at: 30.minutes.ago)
      create_run(status: :failed, started_at: 1.hour.ago)
      create_run(status: :failed, started_at: 2.hours.ago)
      create_run(status: :failed, started_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "keeps the caller controlled candidate scope and threshold" do
      matching = create_run(status: :failed, event_source: "schedule", started_at: 1.hour.ago)
      create_run(status: :failed, event_source: "manual", started_at: 30.minutes.ago)

      entries = described_class.new(
        relation: GeneratedFileRun.where(event_source: "schedule"),
        threshold: 1
      ).call

      expect(entries.size).to eq(1)
      expect(entries.first.event_source).to eq("schedule")
      expect(entries.first.last_failed_at.to_i).to eq(matching.finished_at.to_i)
    end

    it "passes the lookback limit through to the candidate query" do
      matching = create_run(status: :failed, started_at: 1.hour.ago)
      relation = instance_double(ActiveRecord::Relation)
      ordered_relation = instance_double(ActiveRecord::Relation)

      allow(relation).to receive(:order)
        .with(started_at: :desc, created_at: :desc, id: :desc)
        .and_return(ordered_relation)
      allow(ordered_relation).to receive(:limit).with(1).and_return([matching])

      entries = described_class.new(
        relation: relation,
        threshold: 1,
        lookback_limit: 1
      ).call

      expect(ordered_relation).to have_received(:limit).with(1)
      expect(entries.map(&:job_id)).to eq(["docs-build"])
    end

    it "uses a squished preview instead of returning the full raw error message" do
      create_run(
        status: :failed,
        error_message: "first line\nsecond line with a long token",
        started_at: 1.hour.ago
      )

      entry = described_class.new(threshold: 1, error_message_max_length: 24).call.first

      expect(entry.latest_error_message).to eq("first line second line...")
    end
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
