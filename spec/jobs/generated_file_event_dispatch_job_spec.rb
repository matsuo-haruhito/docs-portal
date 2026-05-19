require "rails_helper"

RSpec.describe GeneratedFileEventDispatchJob, type: :job do
  it "dispatches due pending events grouped by event source" do
    due_a = create_event!(path: "docs/a.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago, metadata: {"a" => 1}, occurrences_count: 2)
    due_b = create_event!(path: "docs/b.yml", operation: "delete", event_source: "manual", scheduled_at: Time.current, metadata: {"b" => 2}, occurrences_count: 3)
    future = create_event!(path: "docs/future.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.from_now)
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

  it "marks events failed when dispatch raises" do
    event = create_event!(path: "docs/a.yml", operation: "update", event_source: "manual", scheduled_at: 1.minute.ago)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later).and_raise("boom")

    expect { described_class.perform_now }.to raise_error(RuntimeError, "boom")

    expect(event.reload).to be_failed
    expect(event.error_message).to eq("boom")
  end

  def create_event!(attributes = {})
    defaults = {
      event_key: GeneratedFileEvent.build_event_key(
        path: attributes.fetch(:path, "docs/source.yml"),
        operation: attributes.fetch(:operation, "update"),
        event_source: attributes.fetch(:event_source, "spec")
      ),
      path: "docs/source.yml",
      operation: "update",
      event_source: "spec",
      status: :pending,
      metadata: {},
      scheduled_at: 1.minute.ago,
      last_seen_at: Time.current,
      occurrences_count: 1
    }
    GeneratedFileEvent.create!(defaults.merge(attributes))
  end
end
