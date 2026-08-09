require "rails_helper"

RSpec.describe ExternalFolderSync::Runner do
  around do |example|
    FileUtils.rm_rf(DocumentFile.storage_root.join("external_folder_syncs"))
    example.run
    FileUtils.rm_rf(DocumentFile.storage_root.join("external_folder_syncs"))
  end

  it "notifies generated file create events after applying external file sync" do
    project = create(:project)
    actor = create(:user, :internal)
    source = create(:external_folder_sync_source, project:, created_by: actor)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    client = instance_double(ExternalFolderSync::GoogleDriveClient)
    entry = google_drive_entry(
      id: "drive-file-1",
      name: "decision_flow.yml",
      download_path: "Google Drive Sync/decision_flow.yml",
      checksum: "checksum-v1"
    )

    allow(ExternalFolderSync::GoogleDriveClient).to receive(:new).with(source:).and_return(client)
    allow(client).to receive(:list_files).and_return([entry])
    allow(client).to receive(:start_page_token).and_return("cursor-1")
    allow(client).to receive(:download_entry).with(entry).and_return("flow: []\n")

    run = described_class.new(source:, mode: :apply, actor:, change_event_notifier: notifier).call

    expect(run).to be_completed
    expect(source.external_folder_sync_items.last.document).to be_source_authority_external_folder
    expect(source.reload.cursor).to eq("cursor-1")
    expect(notifier).to have_received(:notify).with(
      file_events: [{"path" => "Google Drive Sync/decision_flow.yml", "operation" => "create"}],
      event_source: "external_folder_sync",
      metadata: {
        external_folder_sync_source_id: source.id,
        project_id: project.id,
        actor_id: actor.id
      }
    )
  end

  it "continues when the current owner crosses the lease deadline without replacement" do
    project = create(:project)
    actor = create(:user, :internal)
    source = create(:external_folder_sync_source, project:, created_by: actor)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    client = instance_double(ExternalFolderSync::GoogleDriveClient)
    run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply)
    ExternalFolderSync::RunLease.claim!(run)

    allow(ExternalFolderSync::GoogleDriveClient).to receive(:new).with(source:).and_return(client)
    allow(client).to receive(:list_files) do
      source.update_columns(sync_lease_expires_at: 1.minute.ago)
      []
    end
    allow(client).to receive(:start_page_token).and_return("cursor-after-expiry")

    result = described_class.new(
      source:,
      mode: :apply,
      actor:,
      run:,
      change_event_notifier: notifier
    ).call

    expect(result).to be_completed
    expect(source.reload).to have_attributes(
      active_sync_run_id: nil,
      sync_lease_expires_at: nil,
      cursor: "cursor-after-expiry"
    )
  end

  it "stops an old worker after its source lease is replaced" do
    project = create(:project)
    actor = create(:user, :internal)
    source = create(:external_folder_sync_source, project:, created_by: actor)
    notifier = instance_double(GeneratedFiles::ChangeEventNotifier, notify: [])
    client = instance_double(ExternalFolderSync::GoogleDriveClient)
    run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply)
    ExternalFolderSync::RunLease.claim!(run)
    replacement_run = nil

    allow(ExternalFolderSync::GoogleDriveClient).to receive(:new).with(source:).and_return(client)
    allow(client).to receive(:list_files) do
      run.update_columns(heartbeat_at: 2.hours.ago)
      source.update_columns(sync_lease_expires_at: 1.minute.ago)
      ExternalFolderSync::RunLease.recover_stale_source!(source)
      replacement_run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply)
      []
    end

    expect do
      described_class.new(source:, mode: :apply, actor:, run:, change_event_notifier: notifier).call
    end.to raise_error(ExternalFolderSync::RunLease::StaleClaimError)

    expect(run.reload).to be_failed
    expect(source.reload.active_sync_run).to eq(replacement_run)
    expect(source.cursor).to be_nil
    expect(source.last_synced_at).to be_nil
    expect(notifier).not_to have_received(:notify)
  end

  def google_drive_entry(id:, name:, download_path:, checksum:)
    ExternalFolderSync::GoogleDriveClient::FileEntry.new(
      id:,
      parent_id: "folder-id",
      name:,
      download_name: name,
      path: download_path,
      download_path:,
      mime_type: "text/yaml",
      download_mime_type: "text/yaml",
      size: 8,
      checksum:,
      modified_at: Time.zone.parse("2026-05-19 10:00:00"),
      trashed: false,
      web_view_link: nil,
      exportable: false,
      export_mime_type: nil
    )
  end
end
