require "rails_helper"

RSpec.describe "Admin generated file events", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
  end

  def bulk_retry_button(filters = {})
    parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_events_path(filters)}"] button[type="submit"]))
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
      expect(response.body).to include("イベントID / パス / エラー")
      expect(response.body).to include("再投入")
      expect(response.body).to include("失敗分を一括再投入")
      expect(response.body).to include("今回の一括再投入対象: 0 件")
      expect(response.body).to include("現在の条件で今回再投入する失敗イベントを、古い順に最大100件まで処理します。")
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
      create_event!(path: "storage/document_files/source.yml", status: :failed, event_source: "manual_document_upload", error_message: "source failed")
      filters = {
        status: "failed",
        operation: "update",
        event_source: "manual_document_upload",
        path: "document_files",
        scheduled_from: "2026-05-10",
        scheduled_to: "2026-05-11",
        q: "source"
      }

      get admin_generated_file_events_path(filters)

      expect(response).to have_http_status(:ok)
      expect(bulk_retry_button(filters)).to be_present
    end

    it "shows active filter summary near result rows without changing the bulk retry boundary" do
      sign_in_as(admin_user)
      create_event!(
        path: "storage/document_files/source.yml",
        status: :failed,
        operation: "update",
        event_source: "manual_document_upload",
        error_message: "source failed",
        scheduled_at: Time.zone.parse("2026-05-10 12:00:00")
      )
      filters = {
        status: "failed",
        operation: "update",
        event_source: "manual_document_upload",
        path: "document_files",
        scheduled_from: "2026-05-10",
        scheduled_to: "2026-05-10",
        q: "source"
      }

      get admin_generated_file_events_path(filters)

      expect(response).to have_http_status(:ok)
      summary = parsed_html.at_css(".generated-file-event-filter-summary")
      expect(summary).to be_present
      expect(summary.text).to include("現在の表示条件")
      expect(summary.text).to include("状態: 失敗")
      expect(summary.text).to include("操作種別: 更新")
      expect(summary.text).to include("イベント発生元:")
      expect(summary.text).to include("パス: document_files")
      expect(summary.text).to include("実行予定日: 2026-05-10〜2026-05-10")
      expect(summary.text).to include("検索語: source")
      expect(summary.text).to include("一括再投入は、この条件に一致する失敗イベントだけを古い順に最大100件まで対象にします。")
      expect(summary.at_css(%(a[href="#{admin_generated_file_events_path}"]))).to be_present
      expect(response.body).to include("再投入は表示件数や表示設定ではなく、現在の条件に一致する失敗イベントだけを対象にする操作です。")
      expect(bulk_retry_button(filters)).to be_present
    end

    it "shows a filtered bulk retry target count and keeps the action enabled" do
      sign_in_as(admin_user)
      matched = create_event!(path: "storage/document_files/source.yml", status: :failed, event_source: "manual_document_upload", error_message: "source failed", scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      create_event!(path: "storage/document_files/processed.yml", status: :processed, event_source: "manual_document_upload", error_message: "source failed", scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      create_event!(path: "storage/other/source.yml", status: :failed, event_source: "manual_document_upload", error_message: "source failed", scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      create_event!(path: "storage/document_files/other-source.yml", status: :failed, event_source: "artifact_import", error_message: "source failed", scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      create_event!(path: "storage/document_files/other.yml", status: :failed, event_source: "manual_document_upload", error_message: "other failed", scheduled_at: Time.zone.parse("2026-05-10 12:00:00"))
      filters = {
        status: "failed",
        event_source: "manual_document_upload",
        path: "document_files",
        scheduled_from: "2026-05-10",
        scheduled_to: "2026-05-10",
        q: "source"
      }

      get admin_generated_file_events_path(filters)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).to include("今回の一括再投入対象: 1 件")
      expect(bulk_retry_button(filters)).to be_present
      expect(bulk_retry_button(filters)["disabled"]).to be_nil
    end

    it "uses normalized path and truncated q filters for the bulk retry target count" do
      sign_in_as(admin_user)
      query_prefix = "bulk-target-#{'x' * 88}"
      matched = create_event!(path: "storage/document_files/source.yml", status: :failed, error_message: query_prefix)
      create_event!(path: "storage/other/source.yml", status: :failed, error_message: query_prefix)
      create_event!(path: "storage/document_files/other.yml", status: :failed, error_message: "different error")
      filters = {
        status: "failed",
        path: "storage\\document_files",
        q: "#{query_prefix}ignored suffix"
      }
      normalized_filters = filters.merge(q: query_prefix)

      get admin_generated_file_events_path(filters)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).to include("今回の一括再投入対象: 1 件")
      expect(bulk_retry_button(normalized_filters)).to be_present
      expect(bulk_retry_button(normalized_filters)["disabled"]).to be_nil
    end

    it "disables bulk retry when the current filters have no failed targets" do
      sign_in_as(admin_user)
      create_event!(path: "docs/processed.yml", status: :processed)

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今回の一括再投入対象: 0 件")
      expect(response.body).to include("対象がないため一括再投入できません。")
      expect(bulk_retry_button).to be_present
      expect(bulk_retry_button["disabled"]).to eq("disabled")
    end

    it "separates initial and filtered empty states" do
      sign_in_as(admin_user)

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生成ファイルイベントはまだありません。")
      expect(response.body).to include("生成対象のファイル変更イベントが蓄積されると")
      expect(response.body).to include("イベント 0 件は、生成処理が成功していることやエラーがないことを示すものではありません。")
      expect(parsed_html.at_css(%(.generated-file-event-initial-empty-state a[href="#{admin_generated_file_runs_path}"]))).to be_present
      expect(response.body).not_to include("すべての生成ファイルイベントを見る")

      get admin_generated_file_events_path(status: "failed")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("検索条件に一致する生成ファイルイベントはありません。")
      expect(parsed_html.at_css(%(.generated-file-event-filter-empty-state a[href="#{admin_generated_file_events_path}"]))).to be_present
      expect(response.body).not_to include("生成ファイル実行履歴を確認する")
    end

    it "caps the displayed bulk retry target count at the dispatch limit" do
      sign_in_as(admin_user)
      101.times do |i|
        create_event!(path: "docs/failed-#{i}.yml", status: :failed)
      end

      get admin_generated_file_events_path(status: "failed")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今回の一括再投入対象: 100 件")
      expect(response.body).to include("現在の条件で今回再投入する失敗イベントを、古い順に最大100件まで処理します。")
      expect(response.body).not_to include("現在の条件で再投入対象: 100 件")
      expect(bulk_retry_button(status: "failed")["disabled"]).to be_nil
    end

    it "keeps active filters on status quick links" do
      sign_in_as(admin_user)
      create_event!(path: "storage/document_files/source.yml", status: :failed, event_source: "manual_document_upload")
      filters = {
        status: "failed",
        operation: "update",
        event_source: "manual_document_upload",
        path: "document_files",
        scheduled_from: "2026-05-10",
        scheduled_to: "2026-05-11",
        q: "source"
      }

      get admin_generated_file_events_path(filters)

      expect(response).to have_http_status(:ok)
      expect(link_hrefs).to include(admin_generated_file_events_path(filters.except(:status)))
      expect(link_hrefs).to include(admin_generated_file_events_path(filters.merge(status: "pending")))
      expect(link_hrefs).to include(admin_generated_file_events_path(filters.merge(status: "processed")))
    end

    it "preserves the current list path in detail links" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :failed, created_at: 1.day.ago)
      25.times do |i|
        create_event!(path: "docs/newer-#{i}.yml", status: :failed)
      end
      return_to_path = admin_generated_file_events_path(status: "failed", path: "docs", page: 2, per_page: 25)

      get return_to_path

      expect(response).to have_http_status(:ok)
      detail_link = parsed_html.at_css(%(a[href="#{admin_generated_file_event_path(event.public_id, return_to: return_to_path)}"]))
      expect(detail_link).to be_present
    end

    it "shows status summary counts" do
      sign_in_as(admin_user)
      create_event!(status: :pending)
      create_event!(status: :failed)
      create_event!(status: :failed, path: "docs/failed-2.yml")

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      failed_summary_card = parsed_html.css(%(a[href="#{admin_generated_file_events_path(status: "failed")}"])).find { |node| node.at_css(".text-2xl.font-bold") }
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

    it "filters by event id, path, and error fragments with q" do
      sign_in_as(admin_user)
      id_event = create_event!(path: "docs/id-target.yml", status: :pending)
      path_event = create_event!(path: "docs/source.yml", status: :pending)
      error_event = create_event!(path: "docs/error.yml", status: :failed, error_message: "Missing token in payload")
      unmatched_event = create_event!(path: "docs/unmatched.yml", status: :processed, error_message: "completed")

      get admin_generated_file_events_path(q: id_event.public_id.last(8))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(id_event.public_id)
      expect(response.body).not_to include(path_event.public_id)
      expect(response.body).not_to include(error_event.public_id)
      expect(response.body).not_to include(unmatched_event.public_id)

      get admin_generated_file_events_path(q: "docs\\source.yml")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(path_event.public_id)
      expect(response.body).not_to include(id_event.public_id)
      expect(response.body).not_to include(error_event.public_id)
      expect(response.body).not_to include(unmatched_event.public_id)

      get admin_generated_file_events_path(q: "Missing token")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(error_event.public_id)
      expect(response.body).not_to include(id_event.public_id)
      expect(response.body).not_to include(path_event.public_id)
      expect(response.body).not_to include(unmatched_event.public_id)
    end

    it "combines q with existing filters" do
      sign_in_as(admin_user)
      matched = create_event!(path: "docs/search-target.yml", status: :failed, operation: "update", event_source: "manual_document_upload", error_message: "Retry timeout")
      unmatched_status = create_event!(path: "docs/search-target.yml", status: :pending, operation: "update", event_source: "manual_document_upload", error_message: "Retry timeout")
      unmatched_source = create_event!(path: "docs/search-target.yml", status: :failed, operation: "update", event_source: "artifact_import", error_message: "Retry timeout")

      get admin_generated_file_events_path(
        status: "failed",
        operation: "update",
        event_source: "manual_document_upload",
        q: "timeout"
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched_status.public_id)
      expect(response.body).not_to include(unmatched_source.public_id)
    end

    it "warns for invalid scheduled date filters without dropping other bulk retry filters" do
      sign_in_as(admin_user)
      pending_event = create_event!(path: "docs/source.yml", status: :pending)
      failed_event = create_event!(path: "docs/failed.yml", status: :failed)

      get admin_generated_file_events_path(scheduled_from: "invalid", scheduled_to: "also-invalid")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pending_event.public_id)
      expect(response.body).to include(failed_event.public_id)
      expect(response.body).to include("実行予定日(開始)「invalid」は日時として解釈できないため、この条件は適用していません。")
      expect(response.body).to include("実行予定日(終了)「also-invalid」は日時として解釈できないため、この条件は適用していません。")
      expect(response.body).to include("今回の一括再投入対象: 1 件")
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
      expect(response.body).to include("失敗")
      expect(response.body).to include("イベントキー")
      expect(response.body).to include("対象パス")
      expect(response.body).to include("操作")
      expect(response.body).to include("更新")
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

    it "shows a back link to the filtered list" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :failed)
      return_to_path = admin_generated_file_events_path(status: "failed", path: "docs", page: 2, per_page: 25)

      get admin_generated_file_event_path(event.public_id, return_to: return_to_path)

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{return_to_path}"]))).to be_present
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
      missing_key_run = create_run!(job_id: "missing_key_job", metadata: {})
      empty_event_ids_run = create_run!(
        job_id: "empty_event_ids_job",
        metadata: {"generated_file_event_public_ids" => []}
      )
      201.times do |i|
        create_run!(
          job_id: "newer_unrelated_job_#{i}",
          metadata: {"generated_file_event_public_ids" => ["gf_evt_other_#{i}"]}
        )
      end

      get admin_generated_file_event_path(event.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("関連実行")
      expect(response.body).to include("このイベントを参照する実行履歴から、関連する最大10件を新しい順に表示します。")
      expect(response.body).not_to include("最新200件")
      expect(response.body).to include(admin_generated_file_run_path(retry_run.public_id))
      expect(response.body).to include(admin_generated_file_run_path(bulk_retry_run.public_id))
      expect(response.body).not_to include(unrelated_run.public_id)
      expect(response.body).not_to include(missing_key_run.public_id)
      expect(response.body).not_to include(empty_event_ids_run.public_id)
      expect(response.body).to include("完了")
      expect(response.body).to include("再実行")
      expect(response.body).to include("一括再実行")
    end

    it "falls back to the index path for protocol-relative return_to values" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :failed)
      invalid_return_to = "//example.com"
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      get admin_generated_file_event_path(event.public_id, return_to: invalid_return_to)

      expect(response).to have_http_status(:ok)
      expect(parsed_html.at_css(%(a[href="#{admin_generated_file_events_path}"]))).to be_present

      post retry_dispatch_admin_generated_file_event_path(event.public_id, return_to: invalid_return_to)

      expect(response).to redirect_to(admin_generated_file_event_path(event.public_id, return_to: admin_generated_file_events_path))
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later)
    end
  end

  describe "POST /admin/generated_file_events/:public_id/retry_dispatch" do
    it "resets event to pending, enqueues dispatch job, and preserves the return path" do
      sign_in_as(admin_user)
      event = create_event!(
        path: "docs/source.yml",
        status: :failed,
        scheduled_at: 1.hour.ago,
        processed_at: 30.minutes.ago,
        error_message: "boom"
      )
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)
      return_to_path = admin_generated_file_events_path(status: "failed", page: 2, per_page: 25)

      post retry_dispatch_admin_generated_file_event_path(event.public_id, return_to: return_to_path)

      expect(response).to redirect_to(admin_generated_file_event_path(event.public_id, return_to: return_to_path))
      expect(flash[:notice]).to eq("生成ファイルイベントの再投入をキューに投入しました。")
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
      completed = create_event!(path: "docs/completed.yml", status: :processed, event_source: "manual_document_upload", error_message: "boom")
      other_source = create_event!(path: "docs/other-source.yml", status: :failed, event_source: "artifact_import", error_message: "boom")
      other_query = create_event!(path: "docs/other-query.yml", status: :failed, event_source: "manual_document_upload", error_message: "other")
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path(event_source: "manual_document_upload", q: "boom")

      expect(response).to redirect_to(admin_generated_file_events_path(event_source: "manual_document_upload", q: "boom"))
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 1 件の再投入をキューに投入しました。")
      expect(matched.reload).to be_pending
      expect(matched.error_message).to be_nil
      expect(matched.processed_at).to be_nil
      expect(completed.reload).to be_processed
      expect(other_source.reload).to be_failed
      expect(other_query.reload).to be_failed
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
    end

    it "does not bulk retry when a non-failed status filter is active" do
      sign_in_as(admin_user)
      failed = create_event!(path: "docs/failed.yml", status: :failed, error_message: "boom")
      processed = create_event!(path: "docs/processed.yml", status: :processed, error_message: "boom")
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path(status: "processed", q: "boom")

      expect(response).to redirect_to(admin_generated_file_events_path(status: "processed", q: "boom"))
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 0 件の再投入をキューに投入しました。")
      expect(failed.reload).to be_failed
      expect(processed.reload).to be_processed
      expect(GeneratedFileEventDispatchJob).not_to have_received(:perform_later)
    end

    it "bulk retries only the oldest failed events up to the dispatch limit" do
      sign_in_as(admin_user)
      events = 101.times.map do |i|
        create_event!(
          path: "docs/limited-#{i}.yml",
          status: :failed,
          created_at: Time.zone.parse("2026-05-10 12:00:00") + i.minutes,
          scheduled_at: Time.zone.parse("2026-05-10 12:00:00") + i.minutes,
          error_message: "limited retry"
        )
      end
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path(status: "failed", q: "limited retry")

      expect(response).to redirect_to(admin_generated_file_events_path(status: "failed", q: "limited retry"))
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 100 件の再投入をキューに投入しました。")
      expect(events.first(100).map { _1.reload.status }.uniq).to eq(["pending"])
      expect(events.last.reload).to be_failed
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
    end

    it "uses normalized path and truncated q filters when bulk retrying" do
      sign_in_as(admin_user)
      query_prefix = "bulk-target-#{'x' * 88}"
      matched = create_event!(path: "storage/document_files/source.yml", status: :failed, error_message: query_prefix)
      unmatched_path = create_event!(path: "storage/other/source.yml", status: :failed, error_message: query_prefix)
      unmatched_query = create_event!(path: "storage/document_files/other.yml", status: :failed, error_message: "different error")
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path(
        status: "failed",
        path: "storage\\document_files",
        q: "#{query_prefix}ignored suffix"
      )

      expect(response).to redirect_to(admin_generated_file_events_path(status: "failed", path: "storage\\document_files", q: query_prefix))
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 1 件の再投入をキューに投入しました。")
      expect(matched.reload).to be_pending
      expect(unmatched_path.reload).to be_failed
      expect(unmatched_query.reload).to be_failed
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once
    end

    it "does not enqueue dispatch when there are no failed events to retry" do
      sign_in_as(admin_user)
      create_event!(path: "docs/processed.yml", status: :processed)
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path

      expect(response).to redirect_to(admin_generated_file_events_path)
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 0 件の再投入をキューに投入しました。")
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