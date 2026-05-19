require "rails_helper"

RSpec.describe GeneratedFileJob, type: :job do
  it "delegates to the generated files runner" do
    runner = instance_double(GeneratedFiles::Runner, call: [])
    allow(GeneratedFiles::Runner).to receive(:new).and_return(runner)

    described_class.perform_now(
      changed_files: ["source.yml"],
      job_ids: ["sample"]
    )

    expect(GeneratedFiles::Runner).to have_received(:new).with(
      changed_files: ["source.yml"],
      job_ids: ["sample"]
    )
    expect(runner).to have_received(:call)
  end
end
