require "rails_helper"

RSpec.describe "Admin member route identifier contracts", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "retries generated file runs via public_id and rejects numeric ids" do
    run = create_generated_file_run!(
      job_id: "ai_usecase_decision_flow",
      status: :failed,
      changed_files: ["source.yml"],
      metadata: { "actor_id" => 123 }
    )

    sign_in_as(admin_user)
    allow(GeneratedFileJob).to receive(:perform_later)

    post retry_run_admin_generated_file_run_path(run.public_id)

    expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: admin_generated_file_runs_path))
    expect(GeneratedFileJob).to have_received(:perform_later).once.with(
      changed_files: ["source.yml"],
      job_ids: ["ai_usecase_decision_flow"],
      event_source: "generated_file_run_retry",
      metadata: hash_including(
        "actor_id" => 123,
        "retry_of_generated_file_run_public_id" => run.public_id,
        "retry_requested_by_user_id" => admin_user.id
      )
    )

    post retry_run_admin_generated_file_run_path(run.id)

    expect(response).to have_http_status(:not_found)
    expect(GeneratedFileJob).to have_received(:perform_later).once
  end

  def create_generated_file_run!(attributes = {})
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
