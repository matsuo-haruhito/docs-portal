require "rails_helper"

RSpec.describe "Admin generated file run search contract", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_runs" do
    it "documents the current q search targets in the filter form" do
      sign_in_as(admin_user)

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("実行ID / パス / エラー / メタデータ")
      expect(response.body).to include("入力パス・変更ファイル・生成パス・エラー文・補助メタデータ")
    end

    it "finds runs by run id, path arrays, error message, and metadata fragments" do
      sign_in_as(admin_user)
      id_run = create_run!(job_id: "id_match")
      source_run = create_run!(job_id: "source_path_match", source_paths: ["docs/source-contract.yml"], changed_files: ["docs/other.yml"], generated_paths: ["generated/other.md"])
      changed_run = create_run!(job_id: "changed_path_match", source_paths: ["docs/other.yml"], changed_files: ["docs/changed-contract.yml"], generated_paths: ["generated/other.md"])
      generated_run = create_run!(job_id: "generated_path_match", source_paths: ["docs/other.yml"], changed_files: ["docs/other.yml"], generated_paths: ["generated/contract.md"])
      error_run = create_run!(job_id: "error_match", status: :failed, error_message: "Renderer contract timeout")
      metadata_run = create_run!(job_id: "metadata_match", metadata: {"trace_id" => "ops-metadata-contract"})
      unmatched_run = create_run!(job_id: "unmatched", source_paths: ["docs/unmatched.yml"], error_message: "completed", metadata: {"trace_id" => "other-marker"})

      expect_search_to_find(id_run.public_id.last(8), id_run, excluding: unmatched_run)
      expect_search_to_find("source-contract", source_run, excluding: unmatched_run)
      expect_search_to_find("changed-contract", changed_run, excluding: unmatched_run)
      expect_search_to_find("generated/contract", generated_run, excluding: unmatched_run)
      expect_search_to_find("renderer contract timeout", error_run, excluding: unmatched_run)
      expect_search_to_find("ops-metadata-contract", metadata_run, excluding: unmatched_run)
    end

    it "combines metadata search with the existing filters" do
      sign_in_as(admin_user)
      matched = create_run!(
        job_id: "matched_job",
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        status: :failed,
        event_source: "manual_document_upload",
        metadata: {"trace_id" => "metadata-filter-contract"},
        created_at: Time.zone.parse("2026-05-10 12:00:00")
      )
      unmatched_status = create_run!(job_id: "matched_job", generator: "ai_usecase_decision_flow", output_writer: "document_version", status: :completed, event_source: "manual_document_upload", metadata: {"trace_id" => "metadata-filter-contract"}, created_at: Time.zone.parse("2026-05-10 12:00:00"))
      unmatched_job = create_run!(job_id: "other_job", generator: "ai_usecase_decision_flow", output_writer: "document_version", status: :failed, event_source: "manual_document_upload", metadata: {"trace_id" => "metadata-filter-contract"}, created_at: Time.zone.parse("2026-05-10 12:00:00"))
      unmatched_date = create_run!(job_id: "matched_job", generator: "ai_usecase_decision_flow", output_writer: "document_version", status: :failed, event_source: "manual_document_upload", metadata: {"trace_id" => "metadata-filter-contract"}, created_at: Time.zone.parse("2026-05-09 12:00:00"))

      get admin_generated_file_runs_path(
        status: "failed",
        job_id: "matched_job",
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        created_from: "2026-05-10",
        created_to: "2026-05-10",
        q: "metadata-filter-contract"
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched_status.public_id)
      expect(response.body).not_to include(unmatched_job.public_id)
      expect(response.body).not_to include(unmatched_date.public_id)
    end

    it "does not search GeneratedFileEvent fields unless a run metadata fragment references them" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/event-only-contract.yml")
      unmatched_run = create_run!(job_id: "unmatched", source_paths: ["docs/other.yml"], metadata: {})

      get admin_generated_file_runs_path(q: "event-only-contract")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("条件に一致する生成ファイル実行履歴はありません。")
      expect(response.body).not_to include(unmatched_run.public_id)
      expect(response.body).not_to include(event.public_id)
    end
  end

  def expect_search_to_find(query, included_run, excluding:)
    get admin_generated_file_runs_path(q: query)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(included_run.public_id)
    expect(response.body).not_to include(excluding.public_id)
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

  def create_event!(attributes = {})
    path = attributes.fetch(:path, "docs/source.yml")
    operation = attributes.fetch(:operation, "update")
    event_source = attributes.fetch(:event_source, "spec")
    defaults = {
      event_key: GeneratedFileEvent.build_event_key(path:, operation:, event_source:),
      path: path,
      operation: operation,
      event_source: event_source,
      status: :pending,
      metadata: {},
      scheduled_at: 1.minute.from_now,
      last_seen_at: Time.current,
      occurrences_count: 1
    }
    GeneratedFileEvent.create!(defaults.merge(attributes))
  end
end
