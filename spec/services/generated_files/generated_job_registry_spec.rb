require "rails_helper"

RSpec.describe GeneratedFiles::GeneratedJobRegistry do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "selects all matching jobs for changed files" do
    registry_path = write_registry(
      jobs: [
        {
          "id" => "filesystem_job",
          "source_paths" => ["source.yml"],
          "watch_paths" => ["generator.rb"],
          "generator" => "sample",
          "output_writer" => "filesystem"
        },
        {
          "id" => "document_version_job",
          "source_paths" => ["source.yml"],
          "generator" => "sample",
          "output_writer" => "document_version",
          "output_options" => {
            "project_code" => "GENERATED",
            "document_slug" => "generated-doc"
          }
        },
        {
          "id" => "unmatched_job",
          "source_paths" => ["other.yml"],
          "generator" => "sample",
          "output_writer" => "filesystem"
        }
      ]
    )

    selected = described_class.new(registry_path:, root: @root).select(changed_files: ["source.yml"])

    expect(selected.map { _1.fetch("id") }).to eq(["filesystem_job", "document_version_job"])
    expect(selected.second.fetch("output_options")).to include(
      "project_code" => "GENERATED",
      "document_slug" => "generated-doc"
    )
  end

  it "selects explicit job ids even when changed files are empty" do
    registry_path = write_registry(
      jobs: [
        {"id" => "first", "source_paths" => ["source.yml"]},
        {"id" => "second", "source_paths" => ["other.yml"]}
      ]
    )

    selected = described_class.new(registry_path:, root: @root).select(
      changed_files: [],
      job_ids: ["second"]
    )

    expect(selected.map { _1.fetch("id") }).to eq(["second"])
  end

  it "normalizes explicit job ids before matching" do
    registry_path = write_registry(
      jobs: [
        {"id" => "123", "source_paths" => ["source.yml"]},
        {"id" => "other", "source_paths" => ["other.yml"]}
      ]
    )

    selected = described_class.new(registry_path:, root: @root).select(
      changed_files: [],
      job_ids: [123, "123", nil]
    )

    expect(selected.map { _1.fetch("id") }).to eq(["123"])
  end

  it "selects jobs when watch paths change" do
    registry_path = write_registry(
      jobs: [
        {"id" => "watched", "source_paths" => ["source.yml"], "watch_paths" => ["generator.rb"]}
      ]
    )

    selected = described_class.new(registry_path:, root: @root).select(changed_files: ["generator.rb"])

    expect(selected.map { _1.fetch("id") }).to eq(["watched"])
  end

  it "normalizes changed files, source paths, and watch paths before matching" do
    registry_path = write_registry(
      jobs: [
        {"id" => "source", "source_paths" => ["./docs/../docs/source.yml"]},
        {"id" => "watch", "source_paths" => ["source.yml"], "watch_paths" => ["./lib/../lib/generator.rb"]}
      ]
    )

    selected = described_class.new(registry_path:, root: @root).select(
      changed_files: ["docs/source.yml", "lib/generator.rb"]
    )

    expect(selected.map { _1.fetch("id") }).to eq(["source", "watch"])
  end

  def write_registry(content)
    path = @root.join("generated-file-jobs.yml")
    path.write(content.to_yaml)
    path
  end
end
