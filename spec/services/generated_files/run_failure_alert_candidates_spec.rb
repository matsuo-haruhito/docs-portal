require "rails_helper"

RSpec.describe GeneratedFiles::RunFailureAlertCandidates do
  describe "#call" do
    it "returns candidates whose latest runs are consecutive failures at the threshold" do
      older_success = create_run(status: :completed, started_at: 4.hours.ago)
      failures = [
        create_run(status: :failed, error_message: "third failure", started_at: 1.hour.ago),
        create_run(status: :failed, error_message: "second failure", started_at: 2.hours.ago),
        create_run(status: :failed, error_message: "first failure", started_at: 3.hours.ago)
      ]

      candidates = described_class.new.call

      expect(candidates.size).to eq(1)
      candidate = candidates.first
      expect(candidate.job_id).to eq("docs-build")
      expect(candidate.generator).to eq("docusaurus")
      expect(candidate.output_writer).to eq("filesystem")
      expect(candidate.event_source).to eq("schedule")
      expect(candidate.failure_count).to eq(3)
      expect(candidate.runs).to eq(failures)
      expect(candidate.latest_error_message).to eq("third failure")
      expect(candidate.last_failed_at.to_i).to eq(failures.first.finished_at.to_i)
      expect(candidate.runs).not_to include(older_success)
    end

    it "does not return a candidate when a later success breaks the failure streak" do
      create_run(status: :completed, started_at: 30.minutes.ago)
      create_run(status: :failed, started_at: 1.hour.ago)
      create_run(status: :failed, started_at: 2.hours.ago)
      create_run(status: :failed, started_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "keeps unrelated run identities separated" do
      create_run(status: :failed, job_id: "docs-build", started_at: 1.hour.ago)
      create_run(status: :failed, job_id: "docs-build", started_at: 2.hours.ago)
      create_run(status: :failed, job_id: "preview-build", started_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "allows the threshold and relation to be scoped by callers" do
      matching = create_run(status: :failed, event_source: "schedule", started_at: 1.hour.ago)
      create_run(status: :failed, event_source: "manual", started_at: 30.minutes.ago)

      candidates = described_class.new(
        relation: GeneratedFileRun.where(event_source: "schedule"),
        threshold: 1
      ).call

      expect(candidates.size).to eq(1)
      expect(candidates.first.runs).to eq([matching])
      expect(candidates.first.event_source).to eq("schedule")
    end

    it "orders candidates by latest failure time and applies the limit" do
      newest = create_failure_streak(job_id: "newest", started_at: 10.minutes.ago)
      create_failure_streak(job_id: "middle", started_at: 20.minutes.ago)
      create_failure_streak(job_id: "oldest", started_at: 30.minutes.ago)

      candidates = described_class.new(limit: 2).call

      expect(candidates.map(&:job_id)).to eq(["newest", "middle"])
      expect(candidates.first.runs.first).to eq(newest)
    end
  end

  def create_failure_streak(job_id:, started_at:)
    latest = create_run(status: :failed, job_id: job_id, started_at: started_at)
    create_run(status: :failed, job_id: job_id, started_at: started_at - 1.minute)
    create_run(status: :failed, job_id: job_id, started_at: started_at - 2.minutes)
    latest
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
