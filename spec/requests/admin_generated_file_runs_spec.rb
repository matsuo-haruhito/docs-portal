require "rails_helper"

RSpec.describe "Admin generated file runs", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

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
      expect(response.body).to include("失敗分を一括再実行")
    end

    it "shows status summary counts" do
      sign_in_as(admin_user)
      create_run!(status: :completed)
      create_run!(status: :failed)
      create_run!(status: :failed, job_id: "other_job")

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      failed_summary_card = parsed_html.css(%(a[href="#{admin_generated_file_runs_path(status: "failed")}"])).find { |node| node.at_css(".text-2xl.font-bold") }
      expect(failed_summary_card).to be_present
      expect(failed_summary_card.text).to include("失敗")
      expect(failed_summary_card.at_css(".text-2xl.font-bold")&.text).to eq("2")
    end

    it "preserves the current list path in detail links" do
      sign_in_as(admin_user)
      run = create_run!(job_id: "ai_usecase_decision_flow", generator: "ai_usecase_decision_flow", status: :failed, created_at: 1.day.ago)
      25.times do |i|
        create_run!(job_id: "newer_job_#{i}", generator: "ai_usecase_decision_flow", status: :failed)
      end
      return_to_path = admin_generated_file_runs_path(status: "failed", generator: "ai_usecase_decision_flow", page: 2, per_page: 25)

      get return_to_path

      expect(response).to have_http_status(:ok)
      detail_link = parsed_html.at_css(%(a[href="#{admin_generated_file_run_path(run.public_id, return_to: return_to_path)}"]))
      expect(detail_link).to be_present
    end

    it "paginates generated file runs" do
      sign_in_as(admin_user)
      newest = create_run!(job_id: "newest", created_at: Time.zone.parse("2026-05-12 12:00:00"))
      middle = create_run!(job_id: "middle", created_at: Time.zone.parse("2026-05-11 12:00:00"))
      oldest = create_run!(job_id: "oldest", created_at: Time.zone.parse("2026-05-10 12:00:00"))

      get admin_generated_file_runs_path(page: 2, per_page: 1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(middle.public_id)
      expect(response.body).not_to include(newest.public_id)
      expect(response.body).not_to include(oldest.public_id)
      expect(response.body).to include("全 3 件 / 2 / 3 ページ")
      expect(response.body).to include("前へ")
      expect(response.body).to include("次へ")
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

    it "preserves the current filters in the bulk retry form action" do
      sign_in_as(admin_user)
      create_run!(status: :failed)
      filters = {
        status: "failed",
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        created_from: "2026-05-10",
        created_to: "2026-05-11"
      }

      get admin_generated_file_runs_path(filters)

      expect(response).to have_http_status(:ok)
      bulk_retry_form = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(filters)}"]))
      expect(bulk_retry_form).to be_present
      expect(bulk_retry_form.at_css("button")&.text).to include("失敗分を一括再実行")
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
      expect(response.body).to include("状態")
      expect(response.body).to include("失敗")
      expect(response.body).to include("ジョブID")
      expect(response.body).to include("ジェネレータ")
      expect(response.body).to include("出力ライター")
      expect(response.body).to include("発生元")
      expect(response.body).to include("開始")
      expect(response.body).to include("完了")
      expect(response.body).to include("入力パス")
      expect(response.body).to include("変更ファイル")
      expect(response.body).to include("生成パス")
      expect(response.body).to include("メタデータ")
      expect(response.body).to include("エラー")
      expect(response.body).to include("boom")
      expect(response.body).to include("generated.md")
    end

    it "shows a back link to the filtered list" do
      sign_in_as(admin_user)
      run = create_run!(job_id: "ai_usecase_decision_flow", status: :failed)
      return_to_path = admin_generated_file_runs_path(status: "failed", generator: "ai_usecase_decision_flow", page: 2, per_page: 25)

      get admin_generated_file_run_path(run.public_id, return_to: return_to_path)

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{return_to_path}"]))).to be_present
    end

    it "shows related event and retry links without crashing on missing records" do
      sign_in_as(admin_user)
      related_event = create_event!(path: "docs/source.yml")
      original_run = create_run!(job_id: "ai_usecase_decision_flow", status: :failed)
      retry_child_run = create_run!(
        job_id: "ai_usecase_decision_flow",
        status: :completed,
        event_source: "generated_file_run_bulk_retry",
        metadata: {
          "retry_of_generated_file_run_public_id" => original_run.public_id,
          "generated_file_event_public_ids" => [related_event.public_id]
        }
      )
      run = create_run!(
        job_id: "ai_usecase_decision_flow",
        status: :failed,
        event_source: "generated_file_run_retry",
        metadata: {
          "generated_file_event_public_ids" => [related_event.public_id, "missing-event"],
          "retry_of_generated_file_run_public_id" => original_run.public_id
        }
      )

      get admin_generated_file_run_path(run.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("関連イベント")
      expect(response.body).to include("再実行元")
      expect(response.body).to include("再実行依頼時刻")
      expect(response.body).to include("この実行から派生した再実行")
      expect(response.body).to include(admin_generated_file_event_path(related_event.public_id))
      expect(response.body).to include(admin_generated_file_run_path(original_run.public_id))
      expect(response.body).to include(admin_generated_file_run_path(retry_child_run.public_id))
      expect(response.body).to include("missing-event")
      expect(response.body).to include("未処理")
      expect(response.body).to include("（未検出）")
      expect(response.body).to include("失敗")
      expect(response.body).to include("完了")
      expect(response.body).to include("再実行")
      expect(response.body).to include("一括再実行")
    end
  end

  describe "POST /admin/generated_file_runs/:public_id/retry_run" do
    it "enqueues a generated file job with the original job id, changed files, and preserves the return path" do
      sign_in_as(admin_user)
      run = create_run!(
        job_id: "ai_usecase_decision_flow",
        status: :failed,
        changed_files: ["source.yml"],
        metadata: {"actor_id" => 123}
      )
      allow(GeneratedFileJob).to receive(:perform_later)
      return_to_path = admin_generated_file_runs_path(status: "failed", page: 2, per_page: 25)

      post retry_run_admin_generated_file_run_path(run.public_id, return_to: return_to_path)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: return_to_path))
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

    it "uses an empty changed file list when retrying runs without changed files" do
      sign_in_as(admin_user)
      run = create_run!(
        job_id: "ai_usecase_decision_flow",
        status: :failed,
        changed_files: []
      )
      allow(GeneratedFileJob).to receive(:perform_later)

      post retry_run_admin_generated_file_run_path(run.public_id)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: admin_generated_file_runs_path))
      expect(GeneratedFileJob).to have_received(:perform_later).with(
        changed_files: [],
        job_ids: ["ai_usecase_decision_flow"],
        event_source: "generated_file_run_retry",
        metadata: hash_including(
          "retry_of_generated_file_run_public_id" => run.public_id,
          "retry_requested_by_user_id" => admin_user.id
        )
      )
    end

    it "falls back to the index path for protocol-relative return_to values" do
      sign_in_as(admin_user)
      run = create_run!(job_id: "ai_usecase_decision_flow", status: :failed)
      invalid_return_to = "//example.com"
      allow(GeneratedFileJob).to receive(:perform_later)

      get admin_generated_file_run_path(run.public_id, return_to: invalid_return_to)

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{admin_generated_file_runs_path}"]))).to be_present

      post retry_run_admin_generated_file_run_path(run.public_id, return_to: invalid_return_to)

      expect(response).to redirect_to(admin_generated_file_run_path(run.public_id, return_to: admin_generated_file_runs_path))
      expect(GeneratedFileJob).to have_received(:perform_later)
    end
  end

  describe "POST /admin/generated_file_runs/retry_failed" do
    it "bulk retries only failed runs matching the current filters and preserves them in the redirect" do
      sign_in_as(admin_user)
      matched = create_run!(
        job_id: "matched_job",
        generator: "ai_usecase_decision_flow",
        status: :failed,
        output_writer: "document_version",
        event_source: "manual_document_upload",
        changed_files: ["matched.yml"],
        created_at: Time.zone.parse("2026-05-10 12:00:00")
      )
      create_run!(job_id: "completed_job", generator: "ai_usecase_decision_flow", status: :completed, output_writer: "document_version", event_source: "manual_document_upload")
      create_run!(job_id: "other_generator_job", generator: "other_generator", status: :failed, output_writer: "document_version", event_source: "manual_document_upload")
      create_run!(job_id: "other_writer_job", generator: "ai_usecase_decision_flow", status: :failed, output_writer: "filesystem", event_source: "manual_document_upload")
      create_run!(job_id: "other_source_job", generator: "ai_usecase_decision_flow", status: :failed, output_writer: "document_version", event_source: "scheduled_sync")
      create_run!(job_id: "other_date_job", generator: "ai_usecase_decision_flow", status: :failed, output_writer: "document_version", event_source: "manual_document_upload", created_at: Time.zone.parse("2026-05-09 12:00:00"))
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
      expect(GeneratedFileJob).to have_received(:perform_later).once.with(
        changed_files: ["matched.yml"],
        job_ids: ["matched_job"],
        event_source: "generated_file_run_bulk_retry",
        metadata: hash_including(
          "retry_of_generated_file_run_public_id" => matched.public_id,
          "retry_requested_by_user_id" => admin_user.id,
          "bulk_retry" => true
        )
      )
    end

    it "uses an empty changed file list when bulk retrying runs without changed files" do
      sign_in_as(admin_user)
      matched = create_run!(job_id: "matched_job", status: :failed, changed_files: [])
      allow(GeneratedFileJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_runs_path

      expect(response).to redirect_to(admin_generated_file_runs_path)
      expect(GeneratedFileJob).to have_received(:perform_later).once.with(
        changed_files: [],
        job_ids: ["matched_job"],
        event_source: "generated_file_run_bulk_retry",
        metadata: hash_including(
          "retry_of_generated_file_run_public_id" => matched.public_id,
          "retry_requested_by_user_id" => admin_user.id,
          "bulk_retry" => true
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
