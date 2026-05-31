require "rails_helper"

RSpec.describe "Admin generated file run filter contracts", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_runs" do
    it "filters by generator without changing the existing status contract" do
      sign_in_as(admin_user)
      matched = create_run!(generator: "ai_usecase_decision_flow", status: :failed)
      unmatched_generator = create_run!(generator: "markdown_export", status: :failed)
      unmatched_status = create_run!(generator: "ai_usecase_decision_flow", status: :completed)

      get admin_generated_file_runs_path(status: "failed", generator: "ai_usecase_decision_flow")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched_generator.public_id)
      expect(response.body).not_to include(unmatched_status.public_id)
    end

    it "shows invalid date warnings and skips only the invalid date conditions" do
      sign_in_as(admin_user)
      run = create_run!(created_at: Time.zone.parse("2026-05-10 12:00:00"))

      get admin_generated_file_runs_path(created_from: "not-a-date", created_to: "also-not-a-date")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(run.public_id)
      expect(response.body).to include("作成日(開始)「not-a-date」は日時として解釈できないため、この条件は適用していません。")
      expect(response.body).to include("作成日(終了)「also-not-a-date」は日時として解釈できないため、この条件は適用していません。")
    end
  end

  describe "POST /admin/generated_file_runs/retry_failed" do
    it "bulk retries the oldest matching failed runs up to the 100 run limit" do
      sign_in_as(admin_user)
      base_time = Time.zone.parse("2026-05-10 00:00:00")
      expected_job_ids = 100.times.map do |index|
        create_run!(
          job_id: "retry-job-#{index}",
          status: :failed,
          generator: "ai_usecase_decision_flow",
          created_at: base_time + index.minutes
        ).job_id
      end
      excluded_run = create_run!(
        job_id: "retry-job-100",
        status: :failed,
        generator: "ai_usecase_decision_flow",
        created_at: base_time + 100.minutes
      )
      create_run!(job_id: "completed-job", status: :completed, generator: "ai_usecase_decision_flow", created_at: base_time - 1.minute)
      create_run!(job_id: "other-generator-job", status: :failed, generator: "markdown_export", created_at: base_time - 2.minutes)
      enqueued_job_ids = []
      allow(GeneratedFileJob).to receive(:perform_later) do |changed_files:, job_ids:, event_source:, metadata:|
        enqueued_job_ids.concat(job_ids)
        expect(changed_files).to eq(["source.yml"])
        expect(event_source).to eq("generated_file_run_bulk_retry")
        expect(metadata).to include(
          "retry_requested_by_user_id" => admin_user.id,
          "bulk_retry" => true
        )
      end

      post retry_failed_admin_generated_file_runs_path(status: "failed", generator: "ai_usecase_decision_flow")

      expect(response).to redirect_to(admin_generated_file_runs_path(status: "failed", generator: "ai_usecase_decision_flow"))
      expect(enqueued_job_ids).to eq(expected_job_ids)
      expect(enqueued_job_ids).not_to include(excluded_run.job_id)
      expect(GeneratedFileJob).to have_received(:perform_later).exactly(100).times
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
