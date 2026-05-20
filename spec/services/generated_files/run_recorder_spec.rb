require "rails_helper"

RSpec.describe GeneratedFiles::RunRecorder do
  it "creates and finishes generated file run records" do
    job = {
      "id" => "sample_job",
      "generator" => "sample_generator",
      "output_writer" => "filesystem",
      "source_paths" => ["source.yml"]
    }

    run = described_class.new.start(
      job: job,
      changed_files: ["source.yml"],
      event_source: "spec",
      metadata: {"actor_id" => 1}
    )

    expect(run).to be_running
    expect(run.job_id).to eq("sample_job")
    expect(run.generator).to eq("sample_generator")
    expect(run.output_writer).to eq("filesystem")
    expect(run.source_paths).to eq(["source.yml"])
    expect(run.changed_files).to eq(["source.yml"])
    expect(run.event_source).to eq("spec")
    expect(run.metadata).to eq("actor_id" => 1)
    expect(run.started_at).to be_present

    run.finish!(status: :completed, generated_paths: ["generated.md"])

    expect(run.reload).to be_completed
    expect(run.generated_paths).to eq(["generated.md"])
    expect(run.finished_at).to be_present
  end

  it "uses empty arrays and metadata for nil optional values" do
    run = described_class.new.start(
      job: {"id" => "sample_job", "source_paths" => nil},
      changed_files: nil,
      event_source: nil,
      metadata: nil
    )

    expect(run).to be_running
    expect(run.source_paths).to eq([])
    expect(run.changed_files).to eq([])
    expect(run.metadata).to eq({})
  end

  it "returns a null run when disabled" do
    run = described_class.new(enabled: false).start(
      job: {"id" => "sample_job"},
      changed_files: [],
      event_source: nil,
      metadata: {}
    )

    expect { run.finish!(status: :completed, generated_paths: []) }.not_to change(GeneratedFileRun, :count)
  end
end
