require "rails_helper"

RSpec.describe ExternalFolderSyncWebhookEventJob, type: :job do
  it "enqueues an external folder sync job for an enabled source" do
    event = create(:external_folder_sync_webhook_event)
    allow(ExternalFolderSyncJob).to receive(:perform_later)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).to have_received(:perform_later).with(event.external_folder_sync_source.id, event.external_folder_sync_source.created_by_id, event.id)
    expect(event.reload).to be_enqueued
    expect(event.error_message).to be_nil
  end

  it "ignores events without a source" do
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: nil)
    allow(ExternalFolderSyncJob).to receive(:perform_later)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload).to be_ignored
    expect(event.error_message).to include("missing or disabled")
  end

  it "ignores events for disabled sources" do
    source = create(:external_folder_sync_source, enabled: false)
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: source)
    allow(ExternalFolderSyncJob).to receive(:perform_later)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload).to be_ignored
    expect(event.error_message).to include("missing or disabled")
  end
end
