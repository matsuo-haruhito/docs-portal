require "rails_helper"
require "rbconfig"
require "stringio"

RSpec.describe "Generated file runner changed file normalization" do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  it "normalizes changed files before selecting jobs and recording runs" do
    registry = write_registry(
      jobs: [
        {
          "id" => "normalized",
          "source_paths" => ["docs/source.yml"],
          "command" => ruby_write_command("generated.txt", "ok"),
          "generated_paths" => ["generated.txt"]
        }
      ]
    )
    recorder = FakeRunRecorder.new

    results = GeneratedFiles::Runner.new(
      registry_path: registry,
      changed_files: ["", "./", "./docs/../docs/source.yml", "docs/source.yml"],
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new,
      run_recorder: recorder
    ).call

    expect(results.map(&:job_id)).to eq(["normalized"])
    expect(recorder.started_payloads.first.fetch(:changed_files)).to eq(["docs/source.yml"])
  end

  def write_registry(content)
    path = @root.join("generated-file-jobs.yml")
    path.write(content.to_yaml)
    path
  end

  def ruby_write_command(path, content)
    "#{Shellwords.escape(RbConfig.ruby)} -e 'File.write(#{path.to_s.inspect}, #{content.to_s.inspect})'"
  end

  class FakeRunRecorder
    attr_reader :started_payloads

    def initialize
      @started_payloads = []
    end

    def start(job:, changed_files:, event_source:, metadata:)
      @started_payloads << {
        job_id: job.fetch("id"),
        changed_files: changed_files,
        event_source: event_source,
        metadata: metadata
      }
      FakeRun.new
    end
  end

  class FakeRun
    def finish!(status:, generated_paths: [], error_message: nil); end
  end
end