require "rails_helper"
require "rbconfig"
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

  it "runs generator jobs through the filesystem output writer" do
    source = @root.join("flow.yml")
    source.write(minimal_flow_yaml)
    registry = write_registry(
      jobs: [
        {
          "id" => "flow",
          "source_paths" => ["flow.yml"],
          "generator" => "ai_usecase_decision_flow",
          "output_writer" => "filesystem",
          "options" => {
            "source_path" => "flow.yml",
            "markdown_path" => "generated/decision-flow.md",
            "plantuml_path" => "generated/decision-flow.puml"
          },
          "generated_paths" => ["generated/decision-flow.md", "generated/decision-flow.puml"]
        }
      ]
    )

    results = described_class.new(
      registry_path: registry,
      changed_files: ["flow.yml"],
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    ).call

    expect(results.map(&:job_id)).to eq(["flow"])
    expect(results.first.generator).to eq("ai_usecase_decision_flow")
    expect(results.first.output_writer).to eq("filesystem")
    expect(results.first.generated_paths).to eq(["generated/decision-flow.md", "generated/decision-flow.puml"])
    expect(@root.join("generated/decision-flow.md")).to exist
    expect(@root.join("generated/decision-flow.puml")).to exist
  end

  it "records generated file runs when a recorder is provided" do
    registry = write_registry(
      jobs: [
        {
          "id" => "recorded",
          "source_paths" => ["source.yml"],
          "command" => ruby_write_command("recorded.txt", "ok"),
          "generated_paths" => ["recorded.txt"]
        }
      ]
    )
    recorder = FakeRunRecorder.new

    described_class.new(
      registry_path: registry,
      changed_files: ["source.yml"],
      event_source: "spec",
      metadata: {"actor_id" => 1},
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new,
      run_recorder: recorder
    ).call

    expect(recorder.started_payloads).to contain_exactly(
      hash_including(
        job_id: "recorded",
        changed_files: ["source.yml"],
        event_source: "spec",
        metadata: {"actor_id" => 1}
      )
    )
    expect(recorder.runs.first.finished_payloads).to contain_exactly(
      {status: :completed, generated_paths: ["recorded.txt"], error_message: nil}
    )
  end

  it "marks recorded runs as failed when execution raises" do
    registry = write_registry(
      jobs: [
        {
          "id" => "failing",
          "source_paths" => ["source.yml"],
          "command" => "#{Shellwords.escape(RbConfig.ruby)} -e 'abort(%q[boom])'",
          "generated_paths" => ["missing.txt"]
        }
      ]
    )
    recorder = FakeRunRecorder.new

    expect do
      described_class.new(
        registry_path: registry,
        changed_files: ["source.yml"],
        root: @root,
        output: StringIO.new,
        error_output: StringIO.new,
        run_recorder: recorder
      ).call
    end.to raise_error(RuntimeError, /generated-file job failed: failing/)

    expect(recorder.runs.first.finished_payloads).to contain_exactly(
      hash_including(status: :failed, generated_paths: [], error_message: "generated-file job failed: failing")
    )
  end

  it "fails closed before running a command for a claim-backed event and skips normal auto retry" do
    event = create(:generated_file_event, scheduled_at: 1.minute.ago)
    claim = GeneratedFiles::EventDispatchLease.claim!([event])
    registry = write_registry(
      jobs: [
        {
          "id" => "claimed-command",
          "source_paths" => ["source.yml"],
          "command" => ruby_write_command("claimed-command.txt", "unsafe"),
          "generated_paths" => ["claimed-command.txt"]
        }
      ]
    )
    recorder = FakeRunRecorder.new
    auto_retry_policy = instance_double(GeneratedFiles::AutoRetryPolicy, enqueue_for: false)

    expect do
      described_class.new(
        registry_path: registry,
        changed_files: ["source.yml"],
        dispatch_claim: claim,
        root: @root,
        output: StringIO.new,
        error_output: StringIO.new,
        run_recorder: recorder,
        auto_retry_policy:
      ).call
    end.to raise_error(GeneratedFiles::Runner::ClaimBackedCommandError)

    expect(@root.join("claimed-command.txt")).not_to exist
    expect(auto_retry_policy).not_to have_received(:enqueue_for)
    expect(recorder.runs.first.finished_payloads).to contain_exactly(
      hash_including(status: :failed)
    )
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

  it "derives document-version identity from the canonical dispatch group" do
    runner = described_class.new(
      changed_files: [],
      metadata: {
        "generated_file_idempotency_group_id" => "group-a",
        "generated_file_event_public_ids" => ["gfe-b", "gfe-a"]
      },
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    )

    expected = Digest::SHA256.hexdigest(
      ["generated-file-document-version", "v2", "document-version-job", "group-a"].join("\0")
    )
    expect(runner.send(:generated_event_idempotency_key, "document-version-job")).to eq(expected)
  end

  it "uses a different document-version identity for an explicit retry group" do
    first = described_class.new(
      changed_files: [],
      metadata: {
        "generated_file_idempotency_group_id" => "group-a",
        "generated_file_event_public_ids" => ["gfe-a"]
      },
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    )
    retry_run = described_class.new(
      changed_files: [],
      metadata: {
        "generated_file_idempotency_group_id" => "group-b",
        "generated_file_event_public_ids" => ["gfe-a"]
      },
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    )

    expect(retry_run.send(:generated_event_idempotency_key, "document-version-job"))
      .not_to eq(first.send(:generated_event_idempotency_key, "document-version-job"))
  end

  it "keeps a stable legacy identity for buffered payloads without a group" do
    runner = described_class.new(
      changed_files: [],
      metadata: {"generated_file_event_public_ids" => ["gfe-b", "gfe-a", "gfe-a"]},
      root: @root,
      output: StringIO.new,
      error_output: StringIO.new
    )

    expected = Digest::SHA256.hexdigest(
      ["generated-file-document-version", "v1", "document-version-job", "gfe-a", "gfe-b"].join("\0")
    )
    expect(runner.send(:generated_event_idempotency_key, "document-version-job")).to eq(expected)
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
    "#{Shellwords.escape(RbConfig.ruby)} -e 'File.write(#{escaped_path}, #{escaped_content})'"
  end

  def minimal_flow_yaml
    {
      "flow" => {
        "title" => "判断フロー",
        "description" => "説明",
        "entry_label" => "開始",
        "default_diagram_language" => "text"
      },
      "questions" => {
        "start" => {"text" => "コード?", "yes" => "code", "no" => "doc"}
      },
      "results" => {
        "code" => {
          "procedure_id" => "PROC-CODE",
          "title" => "コード手順",
          "tool" => "Codex",
          "pattern" => "PAT-CODE",
          "description" => "コード向け",
          "href" => "./procedures/PROC-CODE.md"
        },
        "doc" => {
          "procedure_id" => "PROC-DOC",
          "title" => "文書手順",
          "tool" => "ChatGPT",
          "pattern" => "PAT-DOC",
          "description" => "文書向け",
          "href" => "./procedures/PROC-DOC.md"
        }
      },
      "rule_table" => []
    }.to_yaml
  end

  class FakeRunRecorder
    attr_reader :started_payloads, :runs

    def initialize
      @started_payloads = []
      @runs = []
    end

    def start(job:, changed_files:, event_source:, metadata:)
      run = FakeRun.new
      @runs << run
      @started_payloads << {
        job_id: job.fetch("id"),
        changed_files: changed_files,
        event_source: event_source,
        metadata: metadata
      }
      run
    end
  end

  class FakeRun
    attr_reader :finished_payloads

    def initialize
      @finished_payloads = []
    end

    def finish!(status:, generated_paths: [], error_message: nil)
      @finished_payloads << {status: status, generated_paths: generated_paths, error_message: error_message}
    end
  end
end
