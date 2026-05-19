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
