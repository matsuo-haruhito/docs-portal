require "rails_helper"

RSpec.describe GeneratedFileJob, type: :job do
  it "delegates to the generated files runner" do
    runner = instance_double(GeneratedFiles::Runner, call: [])
    allow(GeneratedFiles::Runner).to receive(:new).and_return(runner)

    described_class.perform_now(
      changed_files: ["source.yml"],
      job_ids: ["sample"],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )

    expect(GeneratedFiles::Runner).to have_received(:new).with(
      changed_files: ["source.yml"],
      job_ids: ["sample"],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )
    expect(runner).to have_received(:call)
  end

  describe ".concurrency_key_for" do
    it "uses sorted job ids when job ids are present" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {job_ids: ["b", "a"], changed_files: ["z.yml"]}
      )

      expect(key).to eq("generated-file-job:ids:a,b")
    end

    it "uses sorted changed files when job ids are absent" do
      key = described_class.concurrency_key_for(
        args: [],
        kwargs: {changed_files: ["b.yml", "a.yml"]}
      )

      expect(key).to eq("generated-file-job:files:a.yml,b.yml")
    end

    it "accepts string keys from serialized job payloads" do
      key = described_class.concurrency_key_for(
        args: [{"job_ids" => ["serialized"], "changed_files" => ["source.yml"]}],
        kwargs: {}
      )

      expect(key).to eq("generated-file-job:ids:serialized")
    end
  end
end
