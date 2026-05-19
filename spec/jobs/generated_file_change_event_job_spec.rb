require "rails_helper"

RSpec.describe GeneratedFileChangeEventJob, type: :job do
  it "delegates to the generated file change event handler" do
    handler = instance_double(GeneratedFiles::ChangeEventHandler, call: [])
    allow(GeneratedFiles::ChangeEventHandler).to receive(:new).and_return(handler)

    described_class.perform_now(
      changed_files: ["source.yml"],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )

    expect(GeneratedFiles::ChangeEventHandler).to have_received(:new).with(
      changed_files: ["source.yml"],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )
    expect(handler).to have_received(:call)
  end
end
