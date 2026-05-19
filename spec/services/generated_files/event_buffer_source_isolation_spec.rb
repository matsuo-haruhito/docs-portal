require "rails_helper"

RSpec.describe "Generated file event buffer source isolation" do
  it "keeps the same path and operation separate for different event sources" do
    dispatcher = class_double(GeneratedFileEventDispatchJob).as_stubbed_const
    scheduled_dispatcher = class_double(GeneratedFileEventDispatchJob, perform_later: true)
    allow(dispatcher).to receive(:set).and_return(scheduled_dispatcher)

    buffer = GeneratedFiles::EventBuffer.new(debounce_seconds: 5, dispatcher_job: dispatcher)

    manual = buffer.add(
      file_events: [{path: "docs/source.yml", operation: "update"}],
      event_source: "manual_document_upload"
    )
    external = buffer.add(
      file_events: [{path: "docs/source.yml", operation: "update"}],
      event_source: "external_folder_sync"
    )

    expect(manual.first).not_to eq(external.first)
    expect(GeneratedFileEvent.pending.pluck(:event_source)).to contain_exactly(
      "manual_document_upload",
      "external_folder_sync"
    )
  end
end
