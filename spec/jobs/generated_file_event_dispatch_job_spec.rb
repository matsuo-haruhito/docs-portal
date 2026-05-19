require "rails_helper"

RSpec.describe GeneratedFileEventDispatchJob, type: :job do
  it "does nothing when there are no due events" do
    create(:generated_file_event, scheduled_at: 1.minute.from_now)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).not_to have_received(:perform_later)
  end

  it "dispatches due pending events grouped by event source" do
    due_a = create(:generated_file_event, path: "docs/a.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago, metadata: {"a" => 1}, occurrences_count: 2)
    due_b = create(:generated_file_event, path: "docs/b.yml", operation: "delete", event_source: "manual", scheduled_at: Time.current, metadata: {"b" => 2}, occurrences_count: 3)
    future = create(:generated_file_event, path: "docs/future.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.from_now)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).to have_received(:perform_later).with(
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
      )
    )
    expect(due_a.reload).to be_processed
    expect(due_b.reload).to be_processed
    expect(future.reload).to be_pending
  end

  it "dispatches separate jobs for separate event sources" do
    manual = create(:generated_file_event, path: "docs/manual.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    external = create(:generated_file_event, path: "docs/external.yml", operation: "update", event_source: "external_folder_sync", scheduled_at: 1.minute.ago)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later)

    described_class.perform_now

    expect(GeneratedFileChangeEventJob).to have_received(:perform_later).with(
      file_events: [{path: manual.path, operation: manual.operation}],
      event_source: "manual",
      metadata: hash_including("generated_file_event_public_ids" => [manual.public_id])
    )
    expect(GeneratedFileChangeEventJob).to have_received(:perform_later).with(
      file_events: [{path: external.path, operation: external.operation}],
      event_source: "external_folder_sync",
      metadata: hash_including("generated_file_event_public_ids" => [external.public_id])
    )
  end

  it "marks all due events failed when dispatch raises" do
    event = create(:generated_file_event, path: "docs/a.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    other_due = create(:generated_file_event, path: "docs/b.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    future = create(:generated_file_event, path: "docs/future.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.from_now)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later).and_raise("boom")

    expect { described_class.perform_now }.to raise_error(RuntimeError, "boom")

    expect(event.reload).to be_failed
    expect(other_due.reload).to be_failed
    expect(future.reload).to be_pending
    expect(event.error_message).to eq("boom")
  end
end
