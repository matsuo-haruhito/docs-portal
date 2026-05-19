require "rails_helper"
require "stringio"

RSpec.describe GeneratedFiles::ChangeEventHandler do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "enqueues matching generated file jobs for changed source files" do
    registry = write_registry(
      jobs: [
        {
          "id" => "matched",
          "source_paths" => ["source.yml"],
          "watch_paths" => ["bin/generate_matched"],
          "command" => "ruby bin/generate_matched",
          "generated_paths" => ["generated.md"]
        },
        {
          "id" => "unmatched",
          "source_paths" => ["other.yml"],
          "command" => "ruby bin/generate_unmatched",
          "generated_paths" => ["other.md"]
        }
      ]
    )
    job_class = class_double(GeneratedFileJob, perform_later: true)

    job_ids = described_class.new(
      changed_files: ["source.yml"],
      event_source: "spec",
      metadata: {"source_id" => 1},
      registry_path: registry,
      root: @root,
      job_class:,
      output: StringIO.new
    ).call

    expect(job_ids).to eq(["matched"])
    expect(job_class).to have_received(:perform_later).with(
      changed_files: ["source.yml"],
      job_ids: ["matched"],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )
  end

  it "enqueues jobs when watch paths change" do
    registry = write_registry(
      jobs: [
        {
          "id" => "watcher",
          "source_paths" => ["source.yml"],
          "watch_paths" => ["bin/generate_watcher"],
          "command" => "ruby bin/generate_watcher",
          "generated_paths" => ["generated.md"]
        }
      ]
    )
    job_class = class_double(GeneratedFileJob, perform_later: true)

    job_ids = described_class.new(
      changed_files: ["bin/generate_watcher"],
      registry_path: registry,
      root: @root,
      job_class:,
      output: StringIO.new
    ).call

    expect(job_ids).to eq(["watcher"])
    expect(job_class).to have_received(:perform_later).with(
      changed_files: ["bin/generate_watcher"],
      job_ids: ["watcher"],
      event_source: nil,
      metadata: {}
    )
  end

  it "does not enqueue when no jobs match" do
    registry = write_registry(
      jobs: [
        {
          "id" => "unmatched",
          "source_paths" => ["source.yml"],
          "command" => "ruby bin/generate_unmatched",
          "generated_paths" => ["generated.md"]
        }
      ]
    )
    job_class = class_double(GeneratedFileJob, perform_later: true)

    job_ids = described_class.new(
      changed_files: ["other.yml"],
      registry_path: registry,
      root: @root,
      job_class:,
      output: StringIO.new
    ).call

    expect(job_ids).to eq([])
    expect(job_class).not_to have_received(:perform_later)
  end

  def write_registry(content)
    path = @root.join("generated-file-jobs.yml")
    path.write(content.to_yaml)
    path
  end
end
