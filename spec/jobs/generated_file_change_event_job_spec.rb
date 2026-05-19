require "rails_helper"

RSpec.describe GeneratedFileChangeEventJob, type: :job do
  it "delegates file CRUD events to the generated file change event handler" do
    handler = instance_double(GeneratedFiles::ChangeEventHandler, call: [])
    allow(GeneratedFiles::ChangeEventHandler).to receive(:new).and_return(handler)

    described_class.perform_now(
      file_events: [{"path" => "source.yml", "operation" => "update"}],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )

    expect(GeneratedFiles::ChangeEventHandler).to have_received(:new).with(
      changed_files: nil,
      file_events: [{"path" => "source.yml", "operation" => "update"}],
      operation: :update,
      event_source: "spec",
      metadata: {"source_id" => 1}
    )
    expect(handler).to have_received(:call)
  end

  it "keeps changed_files as a backward-compatible update event input" do
    handler = instance_double(GeneratedFiles::ChangeEventHandler, call: [])
    allow(GeneratedFiles::ChangeEventHandler).to receive(:new).and_return(handler)

    described_class.perform_now(
      changed_files: ["source.yml"],
      operation: :create
    )

    expect(GeneratedFiles::ChangeEventHandler).to have_received(:new).with(
      changed_files: ["source.yml"],
      file_events: nil,
      operation: :create,
      event_source: nil,
      metadata: {}
    )
    expect(handler).to have_received(:call)
  end
end
