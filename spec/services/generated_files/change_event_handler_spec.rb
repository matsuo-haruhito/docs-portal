require "rails_helper"
require "stringio"

RSpec.describe GeneratedFiles::ChangeEventHandler do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "enqueues configured jobs with expanded params for matching CRUD events" do
    registry = write_registry(
      rules: [
        {
          "id" => "matched",
          "operations" => ["create", "update"],
          "path_patterns" => ["source.yml"],
          "job_class" => "GeneratedFileJob",
          "params" => {
            "changed_files" => "$matched_files",
            "job_ids" => ["generated_job"],
            "event_source" => "$event_source",
            "metadata" => "$metadata"
          }
        },
        {
          "id" => "unmatched",
          "operations" => ["update"],
          "path_patterns" => ["other.yml"],
          "job_class" => "GeneratedFileJob",
          "params" => {
            "changed_files" => "$matched_files",
            "job_ids" => ["other_job"]
          }
        }
      ]
    )
    allow(GeneratedFileJob).to receive(:perform_later)

    rule_ids = described_class.new(
      file_events: [{"path" => "source.yml", "operation" => "update"}],
      event_source: "spec",
      metadata: {"source_id" => 1},
      registry_path: registry,
      root: @root,
      output: StringIO.new
    ).call

    expect(rule_ids).to eq(["matched"])
    expect(GeneratedFileJob).to have_received(:perform_later).with(
      changed_files: ["source.yml"],
      job_ids: ["generated_job"],
      event_source: "spec",
      metadata: {"source_id" => 1}
    )
  end

  it "supports glob path patterns and delete operations" do
    registry = write_registry(
      rules: [
        {
          "id" => "delete_rule",
          "operations" => ["delete"],
          "path_patterns" => ["docs/**/*.yml"],
          "job_class" => "GeneratedFileJob",
          "params" => {
            "changed_files" => "$changed_files",
            "job_ids" => ["cleanup_job"],
            "metadata" => {"operations" => "$operations"}
          }
        }
      ]
    )
    allow(GeneratedFileJob).to receive(:perform_later)

    rule_ids = described_class.new(
      file_events: [
        {"path" => "docs/a/source.yml", "operation" => "delete"},
        {"path" => "docs/a/ignored.md", "operation" => "delete"}
      ],
      registry_path: registry,
      root: @root,
      output: StringIO.new
    ).call

    expect(rule_ids).to eq(["delete_rule"])
    expect(GeneratedFileJob).to have_received(:perform_later).with(
      changed_files: ["docs/a/ignored.md", "docs/a/source.yml"],
      job_ids: ["cleanup_job"],
      metadata: {operations: ["delete"]}
    )
  end

  it "treats changed_files as update events for backward compatibility" do
    registry = write_registry(
      rules: [
        {
          "id" => "legacy_update",
          "operations" => ["update"],
          "path_patterns" => ["source.yml"],
          "job_class" => "GeneratedFileJob",
          "params" => {
            "changed_files" => "$matched_files",
            "job_ids" => ["generated_job"]
          }
        }
      ]
    )
    allow(GeneratedFileJob).to receive(:perform_later)

    rule_ids = described_class.new(
      changed_files: ["source.yml"],
      registry_path: registry,
      root: @root,
      output: StringIO.new
    ).call

    expect(rule_ids).to eq(["legacy_update"])
    expect(GeneratedFileJob).to have_received(:perform_later).with(
      changed_files: ["source.yml"],
      job_ids: ["generated_job"]
    )
  end

  it "does not enqueue when no rules match" do
    registry = write_registry(
      rules: [
        {
          "id" => "unmatched",
          "operations" => ["update"],
          "path_patterns" => ["source.yml"],
          "job_class" => "GeneratedFileJob",
          "params" => {"changed_files" => "$matched_files"}
        }
      ]
    )
    allow(GeneratedFileJob).to receive(:perform_later)

    rule_ids = described_class.new(
      file_events: [{"path" => "other.yml", "operation" => "update"}],
      registry_path: registry,
      root: @root,
      output: StringIO.new
    ).call

    expect(rule_ids).to eq([])
    expect(GeneratedFileJob).not_to have_received(:perform_later)
  end

  def write_registry(content)
    path = @root.join("file-change-event-jobs.yml")
    path.write(content.to_yaml)
    path
  end
end
