require "rails_helper"

RSpec.describe "Admin generated file runs maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }

  around do |example|
    original_value = ENV[Admin::GeneratedFileRunsController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::GeneratedFileRunsController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete(Admin::GeneratedFileRunsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::GeneratedFileRunsController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps the generated file run list and detail readable" do
      sign_in_as(admin_user)
      run = create_run!(status: :failed)

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生成ファイル実行履歴")
      expect(response.body).to include(run.public_id)

      get admin_generated_file_run_path(run.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.public_id)
    end

    it "blocks a single retry without enqueueing a generated file job" do
      sign_in_as(admin_user)
      run = create_run!(status: :failed, changed_files: ["source.yml"])
      allow(GeneratedFileJob).to receive(:perform_later)
      return_to_path = admin_generated_file_runs_path(status: "failed", page: 2, per_page: 25)

      post retry_run_admin_generated_file_run_path(run.public_id, return_to: return_to_path)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: return_to_path))
      expect(GeneratedFileJob).not_to have_received(:perform_later)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("メンテナンス中のため生成ファイルの再実行は停止しています")
    end

    it "blocks bulk retry while preserving the current filters" do
      sign_in_as(admin_user)
      create_run!(
        status: :failed,
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        changed_files: ["matched.yml"],
        created_at: Time.zone.parse("2026-05-10 12:00:00")
      )
      allow(GeneratedFileJob).to receive(:perform_later)
      filters = {
        status: "failed",
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        created_from: "2026-05-10",
        created_to: "2026-05-10"
      }

      post retry_failed_admin_generated_file_runs_path(filters)

      expect(response).to redirect_to(admin_generated_file_runs_path(filters))
      expect(GeneratedFileJob).not_to have_received(:perform_later)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("メンテナンス中のため生成ファイルの再実行は停止しています")
      expect(response.body).to include("ai_usecase_decision_flow")
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing single retry enqueue behavior" do
      sign_in_as(admin_user)
      run = create_run!(status: :failed, changed_files: ["source.yml"])
      allow(GeneratedFileJob).to receive(:perform_later)

      post retry_run_admin_generated_file_run_path(run.public_id)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: admin_generated_file_runs_path))
      expect(GeneratedFileJob).to have_received(:perform_later).once.with(
        changed_files: ["source.yml"],
        job_ids: [run.job_id],
        event_source: "generated_file_run_retry",
        metadata: hash_including(
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
