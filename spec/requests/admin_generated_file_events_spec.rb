require "rails_helper"

RSpec.describe "Admin generated file events", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  describe "GET /admin/generated_file_events" do
    it "shows generated file events for admin users" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :pending)

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生成ファイルイベント")
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("docs/source.yml")
      expect(response.body).to include("再dispatch")
      expect(response.body).to include("失敗分を一括再dispatch")
      expect(response.body).to include("一括再dispatchは古い失敗分から最大100件です。")
    end

    it "shows error messages in the index" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :failed, error_message: "build failed")

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("エラー")
      expect(response.body).to include("build failed")
    end

    it "keeps current filters on the bulk retry form" do
      sign_in_as(admin_user)
      create_event!(path: "storage/document_files/source.yml", status: :failed, event_source: "manual_document_upload")
      filters = {
        status: "failed",
        operation: "update",
        event_source: "manual_document_upload",
        path: "document_files",
        scheduled_from: "2026-05-10",
        scheduled_to: "2026-05-11"
      }

      get admin_generated_file_events_path(filters)

      expect(response).to have_http_status(:ok)
      bulk_retry_form = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_events_path(filters)}"]))
      expect(bulk_retry_form).to be_present
    end

    it "shows status summary counts" do
      sign_in_as(admin_user)
      create_event!(status: :pending)
      create_event!(status: :failed)
      create_event!(status: :failed, path: "docs/failed-2.yml")

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      failed_summary_card = parsed_html.at_css(%(a[href="#{admin_generated_file_events_path(status: "failed")}"]))
      expect(failed_summary_card).to be_present
      expect(failed_summary_card.text).to include("失敗")
      expect(failed_summary_card.at_css(".text-2xl.font-bold")&.text).to eq("2")
    end

    it "paginates generated file events" do
      sign_in_as(admin_user)
      newest = create_event!(path: "docs/newest.yml", scheduled_at: Time.zone.parse("2026-05-12 12:00:00"), created_at: Time.zone.parse("2026-05-12 12:00:00"))
      middle = create_event!(path: "docs/middle.yml", scheduled_at: Time.zone.parse("2026-05-11 12:00:00"), created_at: Time.zone.parse("2026-05-11 12:00:00"))
      oldest = create_event!(path: "docs/oldest.yml", scheduled_at: Time.zone.parse("2026-05-10 12:00:00"), created_at: Time.zone.parse("2026-05-10 12:00:00"))

      get admin_generated_file_events_path(page: 2, per_page: 1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(middle.public_id)
      expect(response.body).not_to include(newest.public_id)
      expect(response.body).not_to include(oldest.public_id)
      expect(response.body).to include("全 3 件 / 2 / 3 ページ")
      expect(response.body).to include("前へ")
      expect(response.body).to include("次へ")
    end

    it "filters by status" do
      sign_in_as(admin_user)
      pending_event = create_event!(path: "docs/pending.yml", status: :pending)
      failed_event = create_event!(path: "docs/failed.yml", status: :failed)

      get admin_generated_file_events_path(status: "failed")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(failed_event.public_id)
      expect(response.body).not_to include(pending_event.public_id)
    end

    it "filters by operation, event source, path, and scheduled date range" do
      sign_in_as(admin_user)
      matched = create_event!(
        path: "storage/document_files/source.yml",
        operation: "update",
        event_source: "manual_document_upload",
        status: :pending,
        scheduled_at: Time.zone.parse("2026-05-10 12:00:00")
      )
      unmatched_operation = create_event!(path: "storage/document_files/source.yml", operation: "delete", event_source: "manual_document_upload", status: :pending, scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      unmatched_source = create_event!(path: "storage/document_files/source.yml", operation: "update", event_source: "artifact_import", status: :pending, scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      unmatched_path = create_event!(path: "other/source.yml", operation: "update", event_source: "manual_document_upload", status: :pending, scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      unmatched_date = create_event!(path: "storage/document_files/source.yml", operation: "update", event_source: "manual_document_upload", status: :pending, scheduled_at: Time.zone.parse("2026-05-01 12:00:00"))

      get admin_generated_file_events_path(
        status: "pending",
        operation: "update",
        event_source: "manual_document_upload",
        path: "document_files",
        scheduled_from: "2026-05-10",
        scheduled_to: "2026-05-10"
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched_operation.public_id)
      expect(response.body).not_to include(unmatched_source.public_id)
      expect(response.body).not_to include(unmatched_path.public_id)
      expect(response.body).not_to include(unmatched_date.public_id)
    end

    it "ignores invalid scheduled date filters" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :pending)

      get admin_generated_file_events_path(scheduled_from: "invalid", scheduled_to: "also-invalid")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)
    end

    it "forbids external users" do
      sign_in_as(create(:user, :external))

      get admin_generated_file_events_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /admin/generated_file_events/:public_id" do
    it "shows event details" do
      sign_in_as(admin_user)
      event = create_event!(
        path: "docs/source.yml",
        status: :failed,
        metadata: {"actor_id" => 1},
        error_message: "boom"
      )

      get admin_generated_file_event_path(event.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("状態")
      expect(response.body).to include("イベントキー")
      expect(response.body).to include("対象パス")
      expect(response.body).to include("操作")
      expect(response.body).to include("発生元")
      expect(response.body).to include("発生回数")
      expect(response.body).to include("予定時刻")
      expect(response.body).to include("最終検知")
      expect(response.body).to include("処理日時")
      expect(response.body).to include("エラー")
      expect(response.body).to include("メタデータ")
      expect(response.body).to include("docs/source.yml")
      expect(response.body).to include("/ 区切りで保存されます。")
      expect(response.body).to include("boom")
      expect(response.body).to include("actor_id")
    end

    it "shows related runs that reference the event" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml")
      retry_run = create_run!(
        job_id: "retry_job",
        event_source: "generated_file_run_retry",
        metadata: {"generated_file_event_public_ids" => [event.public_id]}
      )
      bulk_retry_run = create_run!(
        job_id: "bulk_retry_job",
        event_source: "generated_file_run_bulk_retry",
        metadata: {"generated_file_event_public_ids" => [event.public_id]}
      )
      unrelated_run = create_run!(
        job_id: "unrelated_job",
        metadata: {"generated_file_event_public_ids" => ["gf_evt_other"]}
      )

      get admin_generated_file_event_path(event.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("関連実行")
      expect(response.body).to include(admin_generated_file_run_path(retry_run.public_id))
      expect(response.body).to include(admin_generated_file_run_path(bulk_retry_run.public_id))
      expect(response.body).not_to include(unrelated_run.public_id)
      expect(response.body).to include("再実行")
      expect(response.body).to include("一括再実行")
    end
  end

  describe "POST /admin/generated_file_events/:public_id/retry_dispatch" do
    it "resets event to pending and enqueues dispatch job" do
      sign_in_as(admin_user)
      event = create_event!(
        path: "docs/source.yml",
        status: :failed,
        scheduled_at: 1.hour.ago,
        processed_at: 30.minutes.ago,
        error_message: "boom"
      )
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_dispatch_admin_generated_file_event_path(event.public_id)

      expect(response).to redirect_to(admin_generated_file_event_path(event.public_id))
      expect(flash[:notice]).to eq("生成ファイルイベントの再dispatchをキューに投入しました。")
      event.reload
      expect(event).to be_pending
      expect(event.scheduled_at).to be_within(5.seconds).of(Time.current)
      expect(event.processed_at).to be_nil
      expect(event.error_message).to be_nil
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later)
    end
  end

  describe "POST /admin/generated_file_events/retry_failed" do
    it "bulk retries only failed events matching filters" do
      sign_in_as(admin_user)
      matched = create_event!(path: "docs/matched.yml", status: :failed, event_source: "manual_document_upload", error_message: "boom")
      completed = create_event!(path: "docs/completed.yml", status: :processed, event_source: "manual_document_upload")
      other_source = create_event!(path: "docs/other-source.yml", status: :failed, event_source: "artifact_import", error_message: "boom")
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path(event_source: "manual_document_upload")

      expect(response).to redirect_to(admin_generated_file_events_path(event_source: "manual_document_upload"))
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 1 件の再dispatchをキューに投入しました。")
      expect(matched.reload).to be_pending
      expect(matched.error_message).to be_nil
      expect(matched.processed_at).to be_nil
      expect(completed.reload).to be_processed
      expect(other_source.reload).to be_failed
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
    end

    it "does not enqueue dispatch when there are no failed events to retry" do
      sign_in_as(admin_user)
      create_event!(path: "docs/processed.yml", status: :processed)
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path

      expect(response).to redirect_to(admin_generated_file_events_path)
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 0 件の再dispatchをキューに投入しました。")
      expect(GeneratedFileEventDispatchJob).not_to have_received(:perform_later)
    end
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
