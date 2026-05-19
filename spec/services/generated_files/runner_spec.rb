require "rails_helper"
require "stringio"

RSpec.describe GeneratedFiles::Runner do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "runs jobs whose source paths match changed files" do
    registry = write_registry(
      jobs: [
        {
          "id" => "matched",
          "source_paths" => ["source.yml"],
          "command" => ruby_write_command("generated.txt", "ok"),
          "generated_paths" => ["generated.txt"]
        },
        {
          "id" => "unmatched",
          "source_paths" => ["other.yml"],
          "command" => ruby_write_command("other.txt", "ng"),
          "generated_paths" => ["other.txt"]
        }
      ]
    )

    results = described_class.new(
      registry_path: registry,
      changed_files: ["source.yml"],
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    ).call

    expect(results.map(&:job_id)).to eq(["matched"])
    expect(@root.join("generated.txt")).to exist
    expect(@root.join("generated.txt").read).to eq("ok")
    expect(@root.join("other.txt")).not_to exist
  end

  it "runs explicit job ids regardless of changed files" do
    registry = write_registry(
      jobs: [
        {
          "id" => "explicit",
          "source_paths" => ["source.yml"],
          "command" => ruby_write_command("explicit.txt", "ok"),
          "generated_paths" => ["explicit.txt"]
        }
      ]
    )

    results = described_class.new(
      registry_path: registry,
      changed_files: [],
      job_ids: ["explicit"],
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    ).call

    expect(results.map(&:job_id)).to eq(["explicit"])
    expect(@root.join("explicit.txt").read).to eq("ok")
  end

  it "returns no results when no jobs match" do
    registry = write_registry(
      jobs: [
        {
          "id" => "unmatched",
          "source_paths" => ["source.yml"],
          "command" => ruby_write_command("generated.txt", "ok"),
          "generated_paths" => ["generated.txt"]
        }
      ]
    )

    results = described_class.new(
      registry_path: registry,
      changed_files: ["other.yml"],
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    ).call

    expect(results).to eq([])
    expect(@root.join("generated.txt")).not_to exist
  end

  def write_registry(content)
    path = @root.join("generated-file-jobs.yml")
    path.write(content.to_yaml)
    path
  end

  def ruby_write_command(path, content)
    escaped_path = path.to_s.inspect
    escaped_content = content.to_s.inspect
    "ruby -e 'File.write(#{escaped_path}, #{escaped_content})'"
  end
end
