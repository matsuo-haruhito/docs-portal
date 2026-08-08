require "rails_helper"

RSpec.describe ExternalFolderSyncWebhookEventJob, type: :job do
  before do
    allow(ExternalFolderSyncJob).to receive(:perform_later).and_return(true)
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
  end

  it "reserves an enabled source and its events before enqueueing the sync" do
    event = create(:external_folder_sync_webhook_event)

    described_class.perform_now(event.id)

    run = event.reload.external_folder_sync_run
    expect(run).to be_pending
    expect(event.external_folder_sync_source.reload.active_sync_run).to eq(run)
    expect(event.external_folder_sync_source.sync_lease_expires_at).to be_present
    expect(ExternalFolderSyncJob).to have_received(:perform_later).with(
      event.external_folder_sync_source.id,
      event.external_folder_sync_source.created_by_id,
      event.id,
      run.id
    )
    expect(event).to be_enqueued
    expect(event.error_message).to be_nil
  end

  it "uses the legacy three-argument payload without reserving a run while the rollout gate is off" do
    event = create(:external_folder_sync_webhook_event)
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).to have_received(:perform_later).with(
      event.external_folder_sync_source.id,
      event.external_folder_sync_source.created_by_id,
      event.id
    )
    expect(event.reload).to be_enqueued
    expect(event.external_folder_sync_run).to be_nil
    expect(event.external_folder_sync_source.reload.active_sync_run).to be_nil
  end

  it "terminally ignores an event whose source is unavailable" do
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: nil)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload).to be_ignored
    expect(event.ignored_reason).to eq("source_unavailable")
  end

  it "terminally ignores an event for a disabled source" do
    source = create(:external_folder_sync_source, enabled: false)
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: source)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload).to be_ignored
    expect(event.ignored_reason).to eq("source_unavailable")
  end

  it "keeps a notification received while its source has a fresh running lease" do
    source = create(:external_folder_sync_source)
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: source)
    activate_run(source, status: :running, heartbeat_at: 1.minute.ago, expires_at: 59.minutes.from_now)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload).to be_received
    expect(event.error_message).to eq(ExternalFolderSyncWebhookEvent::RUNNING_COALESCED_ERROR_MESSAGE)
  end

  it "does not create a second reservation after the two-minute coalesce window" do
    source = create(:external_folder_sync_source)
    existing_run = activate_run(source, status: :pending, enqueued_at: 3.minutes.ago, expires_at: 12.minutes.from_now)
    existing_event = create(:external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: existing_run,
      status: :enqueued,
      updated_at: 3.minutes.ago)
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: source)

    described_class.perform_now(event.id)

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(source.external_folder_sync_runs.where(status: %i[pending running])).to contain_exactly(existing_run)
    expect(existing_event.reload).to be_enqueued
    expect(event.reload).to be_received
    expect(event.error_message).to eq(ExternalFolderSyncWebhookEvent::RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE)
  end

  it "coalesces bounded received notifications into one source reservation" do
    source = create(:external_folder_sync_source)
    first = create(:external_folder_sync_webhook_event, external_folder_sync_source: source, received_at: 2.minutes.ago)
    second = create(:external_folder_sync_webhook_event, external_folder_sync_source: source, received_at: 1.minute.ago)

    described_class.perform_now(first.id)

    run = first.reload.external_folder_sync_run
    expect(ExternalFolderSyncJob).to have_received(:perform_later).once.with(
      source.id,
      source.created_by_id,
      first.id,
      run.id
    )
    expect(first).to be_enqueued
    expect(second.reload).to be_enqueued
    expect(second.external_folder_sync_run).to eq(run)
    expect(first.payload_json.fetch("coalesced_webhook_event_ids")).to eq([first.id, second.id])
  end

  it "releases the source reservation and returns every event when enqueue fails" do
    source = create(:external_folder_sync_source)
    first = create(:external_folder_sync_webhook_event, external_folder_sync_source: source, received_at: 2.minutes.ago)
    second = create(:external_folder_sync_webhook_event, external_folder_sync_source: source, received_at: 1.minute.ago)
    allow(ExternalFolderSyncJob).to receive(:perform_later).and_return(nil)

    expect { described_class.perform_now(first.id) }.to raise_error(RuntimeError)

    failed_run = source.external_folder_sync_runs.last
    expect(failed_run).to be_failed
    expect(source.reload.active_sync_run).to be_nil
    expect(source.sync_lease_expires_at).to be_nil
    expect(first.reload).to be_received
    expect(second.reload).to be_received
    expect(first.external_folder_sync_run).to be_nil
    expect(second.external_folder_sync_run).to be_nil
  end

  it "reconciliation dispatches a notification retained during an earlier completed sync" do
    source = create(:external_folder_sync_source)
    event = create(:external_folder_sync_webhook_event, external_folder_sync_source: source)
    run = activate_run(source, status: :running, heartbeat_at: 1.minute.ago, expires_at: 59.minutes.from_now)
    described_class.perform_now(event.id)
    run.update!(status: :completed, finished_at: Time.current)
    source.update!(active_sync_run: nil, sync_lease_expires_at: nil)

    ExternalFolderSyncWebhookEventReconciliationJob.perform_now

    new_run = event.reload.external_folder_sync_run
    expect(new_run).not_to eq(run)
    expect(ExternalFolderSyncJob).to have_received(:perform_later).with(
      source.id,
      source.created_by_id,
      event.id,
      new_run.id
    )
    expect(event).to be_enqueued
  end

  it "does not recover notifications while the reliability rollout gate is off" do
    source = create(:external_folder_sync_source)
    run = activate_run(source, status: :running, heartbeat_at: 2.hours.ago, expires_at: 1.minute.ago)
    event = create(:external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: run,
      status: :processing)
    original_event = event.attributes
    original_run = run.attributes
    original_source = source.reload.attributes
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    ExternalFolderSyncWebhookEventReconciliationJob.perform_now

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload.attributes).to eq(original_event)
    expect(run.reload.attributes).to eq(original_run)
    expect(source.reload.attributes).to eq(original_source)
  end

  it "does not dispatch or recover notifications during read-only maintenance" do
    source = create(:external_folder_sync_source)
    run = activate_run(source, status: :running, heartbeat_at: 2.hours.ago, expires_at: 1.minute.ago)
    event = create(:external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: run,
      status: :processing)
    original_event = event.attributes
    original_run = run.attributes
    original_source = source.attributes
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("READ_ONLY_MAINTENANCE", nil).and_return("true")

    described_class.perform_now(event.id)
    ExternalFolderSyncWebhookEventReconciliationJob.perform_now

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload.attributes).to eq(original_event)
    expect(run.reload.attributes).to eq(original_run)
    expect(source.reload.attributes).to eq(original_source)
  end

  it "recovers an orphaned running lease and reserves its events once" do
    source = create(:external_folder_sync_source)
    orphaned_run = activate_run(source, status: :running, heartbeat_at: 2.hours.ago, expires_at: 1.minute.ago)
    event = create(:external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: orphaned_run,
      status: :processing,
      updated_at: 16.minutes.ago)

    ExternalFolderSyncWebhookEventReconciliationJob.perform_now

    replacement_run = event.reload.external_folder_sync_run
    expect(orphaned_run.reload).to be_failed
    expect(replacement_run).to be_pending
    expect(replacement_run).not_to eq(orphaned_run)
    expect(source.reload.active_sync_run).to eq(replacement_run)
    expect(ExternalFolderSyncJob).to have_received(:perform_later).once.with(
      source.id,
      source.created_by_id,
      event.id,
      replacement_run.id
    )
  end

  it "converges processing events from a terminal run without starting another sync" do
    source = create(:external_folder_sync_source)
    run = source.external_folder_sync_runs.create!(
      status: :completed,
      mode: :apply,
      enqueued_at: 2.minutes.ago,
      started_at: 1.minute.ago,
      finished_at: Time.current
    )
    event = create(:external_folder_sync_webhook_event,
      external_folder_sync_source: source,
      external_folder_sync_run: run,
      status: :processing)

    ExternalFolderSyncWebhookEventReconciliationJob.perform_now

    expect(ExternalFolderSyncJob).not_to have_received(:perform_later)
    expect(event.reload).to be_completed
  end

  it "allows only one child job to claim a source reservation" do
    event = create(:external_folder_sync_webhook_event)
    described_class.perform_now(event.id)
    run = event.reload.external_folder_sync_run
    worker = ExternalFolderSyncJob.new

    first_claim = worker.send(:claim_webhook_events, event, run)
    second_claim = worker.send(:claim_webhook_events, event.reload, run.reload)

    expect(first_claim.map(&:id)).to eq([event.id])
    expect(second_claim).to be_empty
    expect(event.reload).to be_processing
    expect(run.reload).to be_running
  end

  it "fences a delayed child after its reservation has been replaced" do
    event = create(:external_folder_sync_webhook_event)
    described_class.perform_now(event.id)
    old_run = event.reload.external_folder_sync_run
    source = event.external_folder_sync_source
    old_run.update_columns(enqueued_at: 16.minutes.ago)
    source.update_columns(sync_lease_expires_at: 1.minute.ago)

    ExternalFolderSyncWebhookEventReconciliationJob.perform_now
    replacement_run = event.reload.external_folder_sync_run
    allow(ExternalFolderSync::Runner).to receive(:new)

    ExternalFolderSyncJob.perform_now(source.id, source.created_by_id, event.id, old_run.id)

    expect(replacement_run).to be_pending
    expect(ExternalFolderSync::Runner).not_to have_received(:new)
  end

  def activate_run(source, status:, expires_at:, enqueued_at: nil, heartbeat_at: nil)
    run = source.external_folder_sync_runs.create!(
      status:,
      mode: :apply,
      enqueued_at: enqueued_at || 2.minutes.ago,
      started_at: status == :running ? 1.minute.ago : nil,
      heartbeat_at:
    )
    source.update!(active_sync_run: run, sync_lease_expires_at: expires_at)
    run
  end
end
