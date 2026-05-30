require "rails_helper"

RSpec.describe "Admin generated file run search", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_runs" do
    it "finds runs by public id fragment" do
      sign_in_as(admin_user)
      matched = create_run!(job_id: "matched_job")
      unmatched = create_run!(job_id: "unmatched_job")

      get admin_generated_file_runs_path(q: matched.public_id.last(8))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched.public_id)
    end

    it "finds runs by source, changed, or generated path fragments with existing filters" do
      sign_in_as(admin_user)
      matched_source = create_run!(status: :failed, source_paths: ["docs/source/manual.yml"])
      matched_changed = create_run!(status: :failed, changed_files: ["storage/generated/target.md"])
      matched_generated = create_run!(status: :failed, generated_paths: ["docs/generated/result.md"])
      unmatched_status = create_run!(status: :completed, source_paths: ["docs/source/manual.yml"])
      unmatched_path = create_run!(status: :failed, source_paths: ["docs/other.yml"], changed_files: ["docs/other.md"], generated_paths: ["docs/other-result.md"])

      get admin_generated_file_runs_path(status: "failed", q: "docs/source/manual")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched_source.public_id)
      expect(response.body).not_to include(matched_changed.public_id)
      expect(response.body).not_to include(matched_generated.public_id)
      expect(response.body).not_to include(unmatched_status.public_id)
      expect(response.body).not_to include(unmatched_path.public_id)

      get admin_generated_file_runs_path(status: "failed", q: "storage/generated")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched_changed.public_id)
      expect(response.body).not_to include(matched_source.public_id)
      expect(response.body).not_to include(matched_generated.public_id)

      get admin_generated_file_runs_path(status: "failed", q: "generated/result")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched_generated.public_id)
      expect(response.body).not_to include(matched_source.public_id)
      expect(response.body).not_to include(matched_changed.public_id)
    end

    it "distinguishes search empty state from an unfiltered empty list" do
      sign_in_as(admin_user)

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生成ファイル実行履歴はまだありません。")

      get admin_generated_file_runs_path(q: "missing-path")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("条件に一致する生成ファイル実行履歴はありません。")
      expect(response.body).not_to include("生成ファイル実行履歴はまだありません。")
    end

    it "keeps search conditions on status summary links and bulk retry" do
      sign_in_as(admin_user)
      create_run!(status: :failed, source_paths: ["docs/source/manual.yml"])
      filters = { status: "failed", q: "docs/source/manual" }

      get admin_generated_file_runs_path(filters)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_generated_file_runs_path(filters.merge(status: "completed")))
      expect(response.body).to include(retry_failed_admin_generated_file_runs_path(filters))
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
