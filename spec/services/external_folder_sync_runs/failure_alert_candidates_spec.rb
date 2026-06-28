require "rails_helper"

RSpec.describe ExternalFolderSyncRuns::FailureAlertCandidates do
  describe "#call" do
    it "returns candidates whose latest runs are consecutive failed or partial runs at the threshold" do
      source = create_source(name: "Drive Alpha")
      older_success = create_run(source: source, status: :completed, started_at: 4.hours.ago)
      failures = [
        create_run(source: source, status: :partial, error_message: "third failure", started_at: 1.hour.ago),
        create_run(source: source, status: :failed, error_message: "second failure", started_at: 2.hours.ago),
        create_run(source: source, status: :failed, error_message: "first failure", started_at: 3.hours.ago)
      ]

      candidates = described_class.new.call

      expect(candidates.size).to eq(1)
      candidate = candidates.first
      expect(candidate.external_folder_sync_source_id).to eq(source.id)
      expect(candidate.provider).to eq("google_drive")
      expect(candidate.source_name).to eq("Drive Alpha")
      expect(candidate.project_code).to eq(source.project.code)
      expect(candidate.failure_count).to eq(3)
      expect(candidate.runs).to eq(failures)
      expect(candidate.latest_error_message).to eq("third failure")
      expect(candidate.last_failed_at.to_i).to eq(failures.first.finished_at.to_i)
      expect(candidate.source_path).to eq("/admin/external_folder_sync_sources/#{source.to_param}")
      expect(candidate.runs).not_to include(older_success)
    end

    it "does not return a candidate when a later completed run breaks the failure streak" do
      source = create_source
      create_run(source: source, status: :completed, started_at: 30.minutes.ago)
      create_run(source: source, status: :failed, started_at: 1.hour.ago)
      create_run(source: source, status: :partial, started_at: 2.hours.ago)
      create_run(source: source, status: :failed, started_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "keeps different sources separated" do
      source = create_source(name: "Drive Alpha")
      other_source = create_source(name: "Drive Beta", external_folder_id: "folder-beta")
      create_run(source: source, status: :failed, started_at: 1.hour.ago)
      create_run(source: source, status: :failed, started_at: 2.hours.ago)
      create_run(source: other_source, status: :failed, started_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "masks sensitive and private-looking values in the error preview" do
      source = create_source(last_error_message: "fallback token=source-secret")
      latest = create_run(
        source: source,
        status: :failed,
        started_at: 1.hour.ago,
        error_message: "Authorization: Bearer raw-token token=secret /home/app/private https://example.test/file?X-Amz-Signature=abc"
      )
      create_run(source: source, status: :failed, started_at: 2.hours.ago)
      create_run(source: source, status: :failed, started_at: 3.hours.ago)

      candidate = described_class.new.call.first

      expect(candidate.runs.first).to eq(latest)
      expect(candidate.latest_error_message).to include("Authorization: Bearer [FILTERED]")
      expect(candidate.latest_error_message).to include("token=[FILTERED]")
      expect(candidate.latest_error_message).to include("[path omitted]")
      expect(candidate.latest_error_message).to include("[url omitted]")
      expect(candidate.latest_error_message).not_to include("raw-token")
      expect(candidate.latest_error_message).not_to include("secret")
      expect(candidate.latest_error_message).not_to include("/home/app/private")
      expect(candidate.latest_error_message).not_to include("X-Amz-Signature=abc")
    end

    it "allows the threshold and relation to be scoped by callers" do
      source = create_source
      matching = create_run(source: source, status: :failed, started_at: 1.hour.ago)
      create_run(source: source, status: :completed, started_at: 30.minutes.ago)

      candidates = described_class.new(
        relation: ExternalFolderSyncRun.where(id: matching.id),
        threshold: 1
      ).call

      expect(candidates.size).to eq(1)
      expect(candidates.first.runs).to eq([matching])
    end

    it "orders candidates by latest failure time and applies the limit" do
      newest = create_failure_streak(name: "newest", started_at: 10.minutes.ago)
      create_failure_streak(name: "middle", started_at: 20.minutes.ago)
      create_failure_streak(name: "oldest", started_at: 30.minutes.ago)

      candidates = described_class.new(limit: 2).call

      expect(candidates.map(&:source_name)).to eq(["newest", "middle"])
      expect(candidates.first.runs.first).to eq(newest)
    end
  end

  def create_failure_streak(name:, started_at:)
    source = create_source(name: name, external_folder_id: "folder-#{name}")
    latest = create_run(source: source, status: :failed, started_at: started_at)
    create_run(source: source, status: :partial, started_at: started_at - 1.minute)
    create_run(source: source, status: :failed, started_at: started_at - 2.minutes)
    latest
  end

  def create_source(name: "Drive source", external_folder_id: "folder-alpha", last_error_message: nil)
    ExternalFolderSyncSource.create!(
      project: create(:project),
      created_by: create(:user, :internal),
      provider: :google_drive,
      auth_type: :oauth_user,
      name: name,
      folder_url: "https://drive.google.com/drive/folders/#{external_folder_id}",
      external_folder_id: external_folder_id,
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      auth_config: "{}",
      last_error_message: last_error_message,
      enabled: true
    )
  end

  def create_run(source:, status:, started_at:, error_message: "boom")
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: source,
      status: status,
      mode: :dry_run,
      started_at: started_at,
      finished_at: started_at + 1.minute,
      error_message: %i[failed partial].include?(status.to_sym) ? error_message : nil
    )
  end
end
