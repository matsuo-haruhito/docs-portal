require "rails_helper"

RSpec.describe "Generated file event buffer defaults" do
  it "uses update when operation is blank" do
    dispatcher = class_double(GeneratedFileEventDispatchJob).as_stubbed_const
    scheduled_dispatcher = class_double(GeneratedFileEventDispatchJob, perform_later: true)
    allow(dispatcher).to receive(:set).and_return(scheduled_dispatcher)

    events = GeneratedFiles::EventBuffer.new(debounce_seconds: 5, dispatcher_job: dispatcher).add(
      file_events: [{path: "docs/source.yml", operation: ""}],
      event_source: "spec"
    )

    expect(events.first.operation).to eq("update")
  end

  it "uses empty metadata when metadata is nil" do
    dispatcher = class_double(GeneratedFileEventDispatchJob).as_stubbed_const
    scheduled_dispatcher = class_double(GeneratedFileEventDispatchJob, perform_later: true)
    allow(dispatcher).to receive(:set).and_return(scheduled_dispatcher)

    events = GeneratedFiles::EventBuffer.new(debounce_seconds: 5, dispatcher_job: dispatcher).add(
      file_events: [{path: "docs/source.yml", operation: "update"}],
      event_source: "spec",
      metadata: nil
    )

    expect(events.first.metadata).to eq({})
  end
end
