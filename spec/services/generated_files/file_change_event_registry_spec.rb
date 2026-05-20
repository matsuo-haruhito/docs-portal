require "rails_helper"

RSpec.describe GeneratedFiles::FileChangeEventRegistry do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "loads rules from registry config" do
    registry_path = write_registry(
      rules: [
        {
          "id" => "generated_job",
          "operations" => %w[create update],
          "path_patterns" => ["docs/**/*.md"],
          "job_class" => "GeneratedFileJob",
          "params" => {
            "changed_files" => "$matched_files",
            "event_source" => "$event_source"
          }
        }
      ]
    )

    rules = described_class.new(registry_path:, root: @root).rules

    expect(rules.first.fetch("id")).to eq("generated_job")
    expect(rules.first.dig("params", "changed_files")).to eq("$matched_files")
  end

  it "validates registry structure" do
    registry_path = write_registry(
      rules: [
        {
          "id" => "generated_job",
          "operations" => %w[create update delete any],
          "path_patterns" => ["docs/**/*.md"],
          "job_class" => "GeneratedFileJob",
          "params" => {
            "changed_files" => "$matched_files",
            "event_source" => "$event_source",
            "metadata" => "$metadata",
            "operations" => "$operations",
            "debounce_seconds" => 10
          }
        }
      ]
    )

    expect(described_class.new(registry_path:, root: @root).validate!).to eq(true)
  end

  it "raises for invalid registry entries" do
    registry_path = write_registry(
      rules: [
        {
          "id" => "",
          "operations" => ["move"],
          "path_patterns" => [],
          "job_class" => "MissingGeneratedFileJob",
          "params" => {
            "changed_files" => "$typo",
            "debounce_seconds" => 0
          }
        }
      ]
    )

    expect {
      described_class.new(registry_path:, root: @root).validate!
    }.to raise_error(ArgumentError, /file_change_event_jobs.yml is invalid/)
  end

  it "raises for duplicate rule ids" do
    registry_path = write_registry(
      rules: [
        valid_rule("same"),
        valid_rule("same")
      ]
    )

    expect {
      described_class.new(registry_path:, root: @root).validate!
    }.to raise_error(ArgumentError, /duplicate file change event rule id: same/)
  end

  def valid_rule(id)
    {
      "id" => id,
      "operations" => ["update"],
      "path_patterns" => ["docs/**/*.md"],
      "job_class" => "GeneratedFileJob",
      "params" => {"changed_files" => "$matched_files"}
    }
  end

  def write_registry(content)
    path = @root.join("file-change-event-jobs.yml")
    path.write(content.to_yaml)
    path
  end
end
