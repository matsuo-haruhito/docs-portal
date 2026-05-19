require "rails_helper"

RSpec.describe "Admin generated file runs", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_runs" do
    it "shows generated file run history for admin users" do
      sign_in_as(admin_user)
      run = create_run!(job_id: "ai_usecase_decision_flow", status: :completed)

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生成ファイル実行履歴")
      expect(response.body).to include(run.public_id)
      expect(response.body).to include("ai_usecase_decision_flow")
      expect(response.body).to include("再実行")
    end

    it "shows status summary counts" do
      sign_in_as(admin_user)
      create_run!(status: :completed)
      create_run!(status: :failed)
      create_run!(status: :failed, job_id: "other_job")

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("completed")
      expect(response.body).to include("failed")
      expect(response.body).to include(admin_generated_file_runs_path(status: "failed"))
      expect(response.body).to match(%r{<div class="mt-1 text-2xl font-bold">2</div>})
    end

    it "filters by status, job id, output writer, event source, and date range" do
      sign_in_as(admin_user)
      matched = create_run!(
        job_id: "ai_usecase_decision_flow_document_version",
        status: :failed,
        output_writer: "document_version",
        event_source: "manual_document_upload",
        created_at: Time.zone.parse("2026-05-10 12:00:00")
      )
      unmatched_status = create_run!(job_id: "ai_usecase_decision_flow_document_version", status: :completed, output_writer: "document_version", event_source: "manual_document_upload")
      unmatched_job = create_run!(job_id: "other_job", status: :failed, output_writer: "document_version", event_source: "manual_document_upload")
      unmatched_date = create_run!(job_id: "ai_usecase_decision_flow_document_version", status: :failed, output_writer: "document_version", event_source: "manual_document_upload", created_at: Time.zone.parse("2026-05-01 12:00:00"))

      get admin_generated_file_runs_path(
        status: "failed",
        job_id: "ai_usecase_decision_flow_document_version",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        created_from: "2026-05-10",
        created_to: "2026-05-10"
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched_status.public_id)
      expect(response.body).not_to include(unmatched_job.public_id)
      expect(response.body).not_to include(unmatched_date.public_id)
    end

    it "ignores invalid date filters" do
      sign_in_as(admin_user)
      run = create_run!(job_id: "ai_usecase_decision_flow")

      get admin_generated_file_runs_path(created_from: "invalid", created_to: "also-invalid")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.public_id)
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /admin/generated_file_runs/:public_id" do
    it "shows run details" do
      sign_in_as(admin_user)
      run = create_run!(
        job_id: "ai_usecase_decision_flow",
        status: :failed,
        error_message: "boom",
        generated_paths: ["generated.md"]
      )

      get admin_generated_file_run_path(run.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.public_id)
      expect(response.body).to include("boom")
      expect(response.body).to include("generated.md")
    end
  end

  describe "POST /admin/generated_file_runs/:public_id/retry_run" do
    it "enqueues a generated file job with the original job id and changed files" do
      sign_in_as(admin_user)
      run = create_run!(
        job_id: "ai_usecase_decision_flow",
        status: :failed,
        changed_files: ["source.yml"],
        metadata: {"actor_id" => 123}
      )
      allow(GeneratedFileJob).to receive(:perform_later)

      post retry_run_admin_generated_file_run_path(run.public_id)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id))
      expect(GeneratedFileJob).to have_received(:perform_later).with(
        changed_files: ["source.yml"],
        job_ids: ["ai_usecase_decision_flow"],
        event_source: "generated_file_run_retry",
        metadata: hash_including(
          "actor_id" => 123,
          "retry_of_generated_file_run_public_id" => run.public_id,
          "retry_requested_by_user_id" => admin_user.id
        )
      )
    end
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
