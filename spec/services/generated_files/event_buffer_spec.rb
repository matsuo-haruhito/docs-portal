require "rails_helper"

RSpec.describe GeneratedFiles::EventBuffer do
  it "coalesces repeated file events into one pending event" do
    dispatcher = class_double(GeneratedFileEventDispatchJob).as_stubbed_const
    scheduled_dispatcher = instance_double(GeneratedFileEventDispatchJob, perform_later: true)
    allow(dispatcher).to receive(:set).and_return(scheduled_dispatcher)

    buffer = described_class.new(debounce_seconds: 30, dispatcher_job: dispatcher)

    first = buffer.add(
      file_events: [{path: "./docs/source.yml", operation: "update"}],
      event_source: "spec",
      metadata: {"actor_id" => 1}
    )
    second = buffer.add(
      file_events: [{"path" => "docs/source.yml", "operation" => "update"}],
      event_source: "spec",
      metadata: {"request_id" => "abc"}
    )

    expect(first.first).to eq(second.first)
    event = first.first.reload
    expect(event.path).to eq("docs/source.yml")
    expect(event.operation).to eq("update")
    expect(event.event_source).to eq("spec")
    expect(event).to be_pending
    expect(event.occurrences_count).to eq(2)
    expect(event.metadata).to include("actor_id" => 1, "request_id" => "abc")
    expect(event.scheduled_at).to be >= 29.seconds.from_now
    expect(dispatcher).to have_received(:set).with(wait: 30.seconds).twice
    expect(scheduled_dispatcher).to have_received(:perform_later).twice
  end

  it "keeps different operations as separate pending events" do
    dispatcher = class_double(GeneratedFileEventDispatchJob).as_stubbed_const
    scheduled_dispatcher = instance_double(GeneratedFileEventDispatchJob, perform_later: true)
    allow(dispatcher).to receive(:set).and_return(scheduled_dispatcher)

    events = described_class.new(debounce_seconds: 5, dispatcher_job: dispatcher).add(
      file_events: [
        {path: "docs/source.yml", operation: "create"},
        {path: "docs/source.yml", operation: "delete"}
      ],
      event_source: "spec"
    )

    expect(events.map(&:operation)).to contain_exactly("create", "delete")
    expect(GeneratedFileEvent.pending.count).to eq(2)
  end
end
