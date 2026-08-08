require "rails_helper"

RSpec.describe GeneratedFileEventDispatchJob, type: :job do
  before do
    allow(GeneratedFileChangeEventJob).to receive(:perform_now)
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
  end

  it "leaves future events pending" do
    event = create(:generated_file_event, scheduled_at: 1.minute.from_now)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).not_to have_received(:perform_now)
    expect(event.reload).to be_pending
  end

  it "claims due events by source and acknowledges them only after child processing succeeds" do
    due_a = create(:generated_file_event, path: "docs/a.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago, metadata: {"a" => 1}, occurrences_count: 2)
    due_b = create(:generated_file_event, path: "docs/b.yml", operation: "delete", event_source: "manual", scheduled_at: Time.current, metadata: {"b" => 2}, occurrences_count: 3)
    future = create(:generated_file_event, path: "docs/future.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.from_now)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).to have_received(:perform_now).with(
      file_events: [
        {path: due_a.path, operation: due_a.operation},
        {path: due_b.path, operation: due_b.operation}
      ],
      event_source: "manual",
      metadata: hash_including(
        "a" => 1,
        "b" => 2,
        "generated_file_event_public_ids" => [due_a.public_id, due_b.public_id],
        "generated_file_event_occurrences_count" => 5
      ),
      dispatch_claim: an_instance_of(GeneratedFiles::EventDispatchLease::Claim)
    )
    expect(due_a.reload).to be_processed
    expect(due_b.reload).to be_processed
    expect(future.reload).to be_pending
  end

  it "dispatches each source as an independent child operation" do
    manual = create(:generated_file_event, path: "docs/manual.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    external = create(:generated_file_event, path: "docs/external.yml", operation: "update", event_source: "external_folder_sync", scheduled_at: 1.minute.ago)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).to have_received(:perform_now).with(
      file_events: [{path: manual.path, operation: manual.operation}],
      event_source: "manual",
      metadata: hash_including("generated_file_event_public_ids" => [manual.public_id]),
      dispatch_claim: an_instance_of(GeneratedFiles::EventDispatchLease::Claim)
    )
    expect(GeneratedFileChangeEventJob).to have_received(:perform_now).with(
      file_events: [{path: external.path, operation: external.operation}],
      event_source: "external_folder_sync",
      metadata: hash_including("generated_file_event_public_ids" => [external.public_id]),
      dispatch_claim: an_instance_of(GeneratedFiles::EventDispatchLease::Claim)
    )
    expect(manual.reload).to be_processed
    expect(external.reload).to be_processed
  end

  it "marks the claimed group failed when child processing fails" do
    event = create(:generated_file_event, path: "docs/a.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    other_due = create(:generated_file_event, path: "docs/b.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    future = create(:generated_file_event, path: "docs/future.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.from_now)
    allow(GeneratedFileChangeEventJob).to receive(:perform_now).and_raise("boom")

    expect { described_class.perform_now }.to raise_error(RuntimeError)

    expect(event.reload).to be_failed
    expect(other_due.reload).to be_failed
    expect(future.reload).to be_pending
    expect(event.error_message).to be_present
  end

  it "does not automatically adopt a legacy processing event without a dispatch group" do
    event = create(:generated_file_event, path: "docs/stale.yml", event_source: "manual", scheduled_at: 1.hour.ago)
    event.update_columns(status: GeneratedFileEvent.statuses[:processing], updated_at: 16.minutes.ago)
    original_attributes = event.reload.attributes

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).not_to have_received(:perform_now)
    expect(event.reload.attributes).to eq(original_attributes)
  end

  it "passes the claim outside metadata and keeps ownership until child processing returns" do
    event = create(:generated_file_event, path: "docs/claimed.yml", event_source: "manual", scheduled_at: 1.minute.ago)
    observed_claim = nil

    allow(GeneratedFileChangeEventJob).to receive(:perform_now) do |dispatch_claim:, metadata:, **|
      observed_claim = dispatch_claim
      expect(event.reload).to be_processing
      expect(event.dispatch_group_id).to eq(dispatch_claim.group_id)
      expect(event.dispatch_claim_token).to eq(dispatch_claim.token)
      expect(metadata).not_to have_key("dispatch_claim_token")
    end

    described_class.perform_now

    expect(observed_claim).to be_a(GeneratedFiles::EventDispatchLease::Claim)
    expect(event.reload).to be_processed
  end

  it "retries a stale claimed group with the same event ids and a rotated owner token" do
    due_a = create(:generated_file_event, path: "docs/a.yml", event_source: "manual", scheduled_at: 1.minute.ago)
    due_b = create(:generated_file_event, path: "docs/b.yml", event_source: "manual", scheduled_at: 1.minute.ago)
    original_claim = GeneratedFiles::EventDispatchLease.claim!([due_a, due_b])
    GeneratedFileEvent.where(id: original_claim.event_ids).update_all(
      dispatch_heartbeat_at: 16.minutes.ago,
      updated_at: 16.minutes.ago
    )
    observed_claim = nil

    allow(GeneratedFileChangeEventJob).to receive(:perform_now) do |metadata:, **|
      observed_claim = due_a.reload.attributes.slice("dispatch_group_id", "dispatch_claim_token")
      expect(metadata.fetch("generated_file_event_public_ids")).to eq([due_a.public_id, due_b.public_id])
      expect(metadata.fetch("generated_file_event_dispatch_group_id")).to eq(original_claim.group_id)
      expect(metadata.fetch("generated_file_idempotency_group_id")).to eq(original_claim.group_id)
    end

    described_class.perform_now

    expect(observed_claim.fetch("dispatch_group_id")).to eq(original_claim.group_id)
    expect(observed_claim.fetch("dispatch_claim_token")).not_to eq(original_claim.token)
    expect([due_a.reload.status, due_b.reload.status]).to eq(%w[processed processed])
    expect([due_a.dispatch_group_id, due_b.dispatch_group_id]).to all(be_nil)
  end

  it "does not claim or recover events while the reliability rollout gate is off" do
    pending = create(:generated_file_event, scheduled_at: 1.minute.ago)
    claimed = create(:generated_file_event, scheduled_at: 1.hour.ago)
    claim = GeneratedFiles::EventDispatchLease.claim!([claimed])
    claimed.update_columns(dispatch_heartbeat_at: 16.minutes.ago, updated_at: 16.minutes.ago)
    original_attributes = [pending, claimed].to_h do |event|
      [event.id, event.reload.attributes.slice(
        "status",
        "dispatch_group_id",
        "dispatch_claim_token",
        "dispatch_claimed_at",
        "dispatch_heartbeat_at",
        "processed_at",
        "error_message",
        "updated_at"
      )]
    end
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).not_to have_received(:perform_now)
    expect(claimed.reload.dispatch_group_id).to eq(claim.group_id)
    [pending, claimed].each do |event|
      expect(event.reload.attributes.slice(*original_attributes.fetch(event.id).keys))
        .to eq(original_attributes.fetch(event.id))
    end
  end

  it "does not dispatch or recover events during read-only maintenance" do
    pending = create(:generated_file_event, scheduled_at: 1.minute.ago)
    processing = create(:generated_file_event, scheduled_at: 1.hour.ago)
    processing.update_columns(status: GeneratedFileEvent.statuses[:processing], updated_at: 16.minutes.ago)
    original_attributes = [pending, processing].to_h do |event|
      [event.id, event.attributes.slice("status", "scheduled_at", "processed_at", "error_message", "updated_at")]
    end
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("READ_ONLY_MAINTENANCE", nil).and_return("true")

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).not_to have_received(:perform_now)
    [pending, processing].each do |event|
      expect(event.reload.attributes.slice("status", "scheduled_at", "processed_at", "error_message", "updated_at"))
        .to eq(original_attributes.fetch(event.id))
    end
  end
end
