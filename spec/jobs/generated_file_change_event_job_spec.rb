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

  it "uses nil metadata safely when delegating to the handler" do
    handler = instance_double(GeneratedFiles::ChangeEventHandler, call: [])
    allow(GeneratedFiles::ChangeEventHandler).to receive(:new).and_return(handler)

    described_class.perform_now(
      file_events: [{"path" => "source.yml", "operation" => "update"}],
      metadata: nil
    )

    expect(GeneratedFiles::ChangeEventHandler).to have_received(:new).with(
      changed_files: nil,
      file_events: [{"path" => "source.yml", "operation" => "update"}],
      operation: :update,
      event_source: nil,
      metadata: nil
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

  it "buffers events when debounce seconds are specified" do
    buffer = instance_double(GeneratedFiles::EventBuffer, add: [])
    allow(GeneratedFiles::EventBuffer).to receive(:new).and_return(buffer)
    allow(GeneratedFiles::ChangeEventHandler).to receive(:new)

    described_class.perform_now(
      changed_files: ["source.yml"],
      operation: :update,
      event_source: "spec",
      metadata: {"source_id" => 1},
      debounce_seconds: 15
    )

    expect(GeneratedFiles::EventBuffer).to have_received(:new).with(debounce_seconds: 15)
    expect(buffer).to have_received(:add).with(
      file_events: [{path: "source.yml", operation: :update}],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )
    expect(GeneratedFiles::ChangeEventHandler).not_to have_received(:new)
  end

  describe ".concurrency_key_for" do
    it "uses sorted normalized file events when file events are present" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {
          file_events: [
            {path: "./docs/b.yml", operation: "delete"},
            {"path" => "docs/../docs/a.yml", "operation" => "update"}
          ]
        }
      )

      expect(key).to eq("generated-file-change-event:docs/a.yml:update,docs/b.yml:delete")
    end

    it "uses update for missing or blank file event operations" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {
          file_events: [
            {path: "docs/missing.yml"},
            {path: "docs/blank.yml", operation: ""}
          ]
        }
      )

      expect(key).to eq("generated-file-change-event:docs/blank.yml:update,docs/missing.yml:update")
    end

    it "ignores blank file event paths" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {
          file_events: [
            {path: "", operation: "update"},
            {path: "./", operation: "delete"},
            {path: "docs/source.yml", operation: "update"}
          ]
        }
      )

      expect(key).to eq("generated-file-change-event:docs/source.yml:update")
    end

    it "uses changed files and operation when file events are absent" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {changed_files: ["b.yml", "a.yml"], operation: :create}
      )

      expect(key).to eq("generated-file-change-event:a.yml:create,b.yml:create")
    end

    it "ignores blank changed files" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {changed_files: ["", "./", "source.yml"], operation: :update}
      )

      expect(key).to eq("generated-file-change-event:source.yml:update")
    end

    it "accepts string keys from serialized job payloads" do
      key = described_class.concurrency_key_for(
        args: [{"changed_files" => ["source.yml"], "operation" => "delete"}],
        kwargs: {}
      )

      expect(key).to eq("generated-file-change-event:source.yml:delete")
    end
  end
end
