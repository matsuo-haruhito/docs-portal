require "rails_helper"

RSpec.describe ExternalFolderSyncJob, type: :job do
  describe ".enqueue_for" do
    it "uses the legacy two-argument payload while the rollout gate is off" do
      source = create(:external_folder_sync_source)
      allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
      allow(described_class).to receive(:perform_later).and_return(true)

      described_class.enqueue_for(source:)

      expect(described_class).to have_received(:perform_later).with(source.id, source.created_by_id)
      expect(source.external_folder_sync_runs).to be_empty
    end

    it "reserves a run and uses the fenced four-argument payload after activation" do
      source = create(:external_folder_sync_source)
      allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
      allow(described_class).to receive(:perform_later).and_return(true)

      described_class.enqueue_for(source:)

      run = source.reload.active_sync_run
      expect(run).to be_pending
      expect(described_class).to have_received(:perform_later).with(
        source.id,
        source.created_by_id,
        nil,
        run.id
      )
    end
  end

  describe "#perform" do
    it "does not claim a queued four-argument run while the rollout gate is off" do
      source = create(:external_folder_sync_source)
      run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply)
      original_run = run.attributes
      original_source = source.reload.attributes
      allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
      allow(ExternalFolderSync::Runner).to receive(:new)

      described_class.perform_now(source.id, source.created_by_id, nil, run.id)

      expect(ExternalFolderSync::Runner).not_to have_received(:new)
      expect(run.reload.attributes).to eq(original_run)
      expect(source.reload.attributes).to eq(original_source)
    end

    it "does not recover a legacy active owner while the rollout gate is off" do
      source = create(:external_folder_sync_source)
      active_run = source.external_folder_sync_runs.create!(
        mode: :apply,
        status: :running,
        enqueued_at: 2.hours.ago,
        started_at: 2.hours.ago,
        heartbeat_at: 2.hours.ago
      )
      source.update!(active_sync_run: active_run, sync_lease_expires_at: 1.minute.ago)
      original_run = active_run.attributes
      original_source = source.reload.attributes
      allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
      allow(ExternalFolderSync::Runner).to receive(:new)

      expect { described_class.perform_now(source.id, source.created_by_id) }
        .not_to change(ExternalFolderSyncRun, :count)

      expect(ExternalFolderSync::Runner).not_to have_received(:new)
      expect(active_run.reload.attributes).to eq(original_run)
      expect(source.reload.attributes).to eq(original_source)
    end

    it "preserves reconciliation state when a replaced worker reports a stale claim" do
      source = create(:external_folder_sync_source)
      run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply)
      event = create(
        :external_folder_sync_webhook_event,
        external_folder_sync_source: source,
        external_folder_sync_run: run,
        status: :enqueued
      )
      runner = instance_double(ExternalFolderSync::Runner)
      allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
      allow(ExternalFolderSync::Runner).to receive(:new).and_return(runner)
      allow(runner).to receive(:call) do
        source.update_columns(sync_lease_expires_at: 1.minute.ago)
        ExternalFolderSync::RunLease.recover_stale_source!(source)
        raise ExternalFolderSync::RunLease::StaleClaimError, "lease replaced"
      end

      expect do
        described_class.perform_now(source.id, source.created_by_id, event.id, run.id)
      end.not_to raise_error

      expect(run.reload).to be_failed
      expect(event.reload).to be_received
      expect(event.external_folder_sync_run).to be_nil
      expect(event.error_message).to eq(ExternalFolderSyncWebhookEvent::STALE_DELIVERY_RECOVERED_ERROR_MESSAGE)
    end

    it "terminalizes a claimed run, source lease, and webhook event when post-reservation preflight fails" do
      source = create(:external_folder_sync_source, enabled: true)
      run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply)
      event = create(
        :external_folder_sync_webhook_event,
        external_folder_sync_source: source,
        external_folder_sync_run: run,
        status: :enqueued,
        payload_json: {"resource_id" => "changed-file"}
      )
      source.update!(enabled: false)
      allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)

      expect do
        described_class.perform_now(source.id, source.created_by_id, event.id, run.id)
      end.to raise_error(ExternalFolderSync::Runner::Error, /Sync source is disabled/)

      expect(run.reload).to have_attributes(status: "failed", finished_at: be_present)
      expect(source.reload).to have_attributes(
        active_sync_run_id: nil,
        sync_lease_expires_at: nil,
        last_error_message: "Sync source is disabled"
      )
      expect(event.reload).to have_attributes(
        status: "failed",
        external_folder_sync_run_id: run.id,
        error_message: "Sync source is disabled"
      )
      expect(event.payload_json.fetch("sync_run")).to include(
        "id" => run.id,
        "public_id" => run.public_id,
        "status" => "failed"
      )
    end
  end
end
