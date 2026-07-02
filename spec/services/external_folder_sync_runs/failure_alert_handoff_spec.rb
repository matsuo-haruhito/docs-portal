require "rails_helper"

RSpec.describe ExternalFolderSyncRuns::FailureAlertHandoff do
  describe "#call" do
    it "returns handoff payload entries for consecutive failed or partial sync candidates" do
      source = create_source(name: "Drive Alpha")
      failures = [
        create_run(source: source, status: :partial, error_message: "third failure", started_at: 1.hour.ago),
        create_run(source: source, status: :failed, error_message: "second failure", started_at: 2.hours.ago),
        create_run(source: source, status: :failed, error_message: "first failure", started_at: 3.hours.ago)
      ]

      entries = described_class.new.call

      expect(entries.size).to eq(1)
      entry = entries.first
      expect(entry.source_name).to eq("Drive Alpha")
      expect(entry.provider).to eq("google_drive")
      expect(entry.project_code).to eq(source.project.code)
      expect(entry.project_name).to eq(source.project.name)
      expect(entry.failure_count).to eq(3)
      expect(entry.last_failed_at.to_i).to eq(failures.first.finished_at.to_i)
      expect(entry.latest_error_message).to eq("third failure")
      expect(entry.source_path).to eq("/admin/external_folder_sync_sources/#{source.to_param}")
      expect(entry.runbook_path).to eq("docs/外部フォルダ同期継続失敗候補runbook.md")
      expect(entry.to_h).to include(
        source_name: "Drive Alpha",
        provider: "google_drive",
        failure_count: 3,
        latest_error_message: "third failure"
      )
    end

    it "keeps the caller controlled candidate scope and threshold" do
      source = create_source
      matching = create_run(source: source, status: :failed, started_at: 1.hour.ago)
      create_run(source: source, status: :completed, started_at: 30.minutes.ago)

      entries = described_class.new(
        relation: ExternalFolderSyncRun.where(id: matching.id),
        threshold: 1
      ).call

      expect(entries.size).to eq(1)
      expect(entries.first.last_failed_at.to_i).to eq(matching.finished_at.to_i)
    end

    it "uses a safe squished error preview without raw secrets, private paths, or signed URLs" do
      source = create_source
      create_run(
        source: source,
        status: :failed,
        started_at: 1.hour.ago,
        error_message: "Authorization: Bearer raw-token\ntoken=secret /home/app/private https://example.test/file?X-Amz-Signature=abc"
      )
      create_run(source: source, status: :failed, started_at: 2.hours.ago)
      create_run(source: source, status: :failed, started_at: 3.hours.ago)

      entry = described_class.new(error_message_max_length: 120).call.first

      expect(entry.latest_error_message).to include("Authorization: Bearer [FILTERED]")
      expect(entry.latest_error_message).to include("token=[FILTERED]")
      expect(entry.latest_error_message).to include("[path omitted]")
      expect(entry.latest_error_message).to include("[url omitted]")
      expect(entry.latest_error_message).not_to include("raw-token")
      expect(entry.latest_error_message).not_to include("secret")
      expect(entry.latest_error_message).not_to include("/home/app/private")
      expect(entry.latest_error_message).not_to include("X-Amz-Signature=abc")
      expect(entry.latest_error_message).not_to include("\n")
    end
  end

  describe ".markdown" do
    it "renders a read-only handoff digest without implying notification, ack, SLA, retry, or provider health" do
      source = create_source(name: "Drive Alpha")
      latest = create_run(source: source, status: :partial, error_message: "provider timeout", started_at: 1.hour.ago)
      create_run(source: source, status: :failed, started_at: 2.hours.ago)
      create_run(source: source, status: :failed, started_at: 3.hours.ago)
      entry = described_class.new.call.first

      markdown = described_class.markdown([entry])

      expect(markdown).to include("## 外部フォルダ同期継続失敗候補 digest")
      expect(markdown).to include("通知・ack・SLA・自動 retry・provider 正常判定の状態ではない read-only preview")
      expect(markdown).to include("- source: Drive Alpha")
      expect(markdown).to include("  - provider: google_drive")
      expect(markdown).to include("  - project: #{source.project.code} #{source.project.name}")
      expect(markdown).to include("  - consecutive_failed_or_partial: 3")
      expect(markdown).to include("  - last_failed_at: #{latest.finished_at.iso8601}")
      expect(markdown).to include("  - error_preview: provider timeout")
      expect(markdown).to include("  - source_path: /admin/external_folder_sync_sources/#{source.to_param}")
      expect(markdown).to include("Runbook: docs/外部フォルダ同期継続失敗候補runbook.md")
      expect(markdown).to include("All error sources: /admin/external_folder_sync_sources?review=errors")
    end

    it "renders a zero-candidate digest as a non-guarantee" do
      markdown = described_class.markdown([])

      expect(markdown).to include("候補 0 件です。")
      expect(markdown).to include("外部 provider 全体正常、通知済み、ack 済み、自動 retry 済みを意味しません")
    end
  end

  def create_source(name: "Drive source", external_folder_id: "folder-alpha")
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
