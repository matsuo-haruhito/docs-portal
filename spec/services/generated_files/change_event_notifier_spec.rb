require "rails_helper"

RSpec.describe GeneratedFiles::ChangeEventNotifier do
  it "normalizes file events and enqueues a file change event job" do
    job_class = class_double(GeneratedFileChangeEventJob, perform_later: true)
    notifier = described_class.new(job_class:)

    events = notifier.notify(
      file_events: [
        {"path" => "./docs/source.yml", "operation" => "update"},
        {path: "docs/source.yml", operation: "update"},
        "docs/other.yml"
      ],
      event_source: "spec",
      metadata: {"actor_id" => 1}
    )

    expect(events).to eq([
      {path: "docs/source.yml", operation: "update"},
      {path: "docs/other.yml", operation: "update"}
    ])
    expect(job_class).to have_received(:perform_later).with(
      file_events: events,
      event_source: "spec",
      metadata: {"actor_id" => 1}
    )
  end

  it "uses update when operation is blank" do
    job_class = class_double(GeneratedFileChangeEventJob, perform_later: true)
    notifier = described_class.new(job_class:)

    events = notifier.notify(
      file_events: [{path: "docs/source.yml", operation: ""}],
      event_source: "spec"
    )

    expect(events).to eq([{path: "docs/source.yml", operation: "update"}])
  end

  it "uses empty metadata when metadata is nil" do
    job_class = class_double(GeneratedFileChangeEventJob, perform_later: true)
    notifier = described_class.new(job_class:)

    events = notifier.notify(
      file_events: ["docs/source.yml"],
      event_source: "spec",
      metadata: nil
    )

    expect(job_class).to have_received(:perform_later).with(
      file_events: events,
      event_source: "spec",
      metadata: {}
    )
  end

  it "does not enqueue when no valid paths are present" do
    job_class = class_double(GeneratedFileChangeEventJob, perform_later: true)
    notifier = described_class.new(job_class:)

    events = notifier.notify(file_events: ["", nil], event_source: "spec")

    expect(events).to eq([])
    expect(job_class).not_to have_received(:perform_later)
  end
end
