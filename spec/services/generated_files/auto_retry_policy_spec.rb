require "rails_helper"

RSpec.describe GeneratedFiles::AutoRetryPolicy do
  subject(:policy) { described_class.new }

  before do
    allow(GeneratedFileJob).to receive(:perform_later)
  end

  it "enqueues one automatic retry for the ai usecase filesystem failed run" do
    run = create_run!(
      job_id: "ai_usecase_decision_flow",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :failed,
      changed_files: ["storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml"],
      metadata: {"generated_file_event_public_ids" => ["gfe_123"]}
    )

    expect(policy.enqueue_for(run)).to eq(true)

    expect(GeneratedFileJob).to have_received(:perform_later).once.with(
      changed_files: ["storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml"],
      job_ids: ["ai_usecase_decision_flow"],
      event_source: "generated_file_run_auto_retry",
      metadata: hash_including(
        "generated_file_event_public_ids" => ["gfe_123"],
        "retry_of_generated_file_run_public_id" => run.public_id,
        "retry_requested_by_user_id" => nil,
        "auto_retry" => true,
        "retry_reason" => "auto_retry_generated_file_run_failed"
      )
    )
  end

  it "does not enqueue another automatic retry when a child retry already exists" do
    run = create_run!(
      job_id: "ai_usecase_decision_flow",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :failed
    )
    create_run!(
      job_id: "ai_usecase_decision_flow",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :failed,
      event_source: "generated_file_run_auto_retry",
      metadata: {
        "retry_of_generated_file_run_public_id" => run.public_id,
        "auto_retry" => true
      }
    )

    expect(policy.enqueue_for(run)).to eq(false)
    expect(GeneratedFileJob).not_to have_received(:perform_later)
  end

  it "does not retry retry-runs, non-target writers, non-target jobs, or non-failed runs" do
    parent = create_run!(
      job_id: "ai_usecase_decision_flow",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :failed
    )
    retry_child = create_run!(
      job_id: "ai_usecase_decision_flow",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :failed,
      metadata: {"retry_of_generated_file_run_public_id" => parent.public_id}
    )
    document_version_run = create_run!(
      job_id: "ai_usecase_decision_flow_document_version",
      generator: "ai_usecase_decision_flow",
      output_writer: "document_version",
      status: :failed
    )
    other_job_run = create_run!(
      job_id: "other_job",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :failed
    )
    completed_run = create_run!(
      job_id: "ai_usecase_decision_flow",
      generator: "ai_usecase_decision_flow",
      output_writer: "filesystem",
      status: :completed
    )

    aggregate_failures do
      expect(policy.enqueue_for(retry_child)).to eq(false)
      expect(policy.enqueue_for(document_version_run)).to eq(false)
      expect(policy.enqueue_for(other_job_run)).to eq(false)
      expect(policy.enqueue_for(completed_run)).to eq(false)
    end
    expect(GeneratedFileJob).not_to have_received(:perform_later)
  end

  def create_run!(attributes = {})
    defaults = {
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :completed,
      event_source: "spec",
      source_paths: ["source.yml"],
      changed_files: ["source.yml"],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    }
    GeneratedFileRun.create!(defaults.merge(attributes))
  end
end
