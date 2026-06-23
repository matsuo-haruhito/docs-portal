require "rails_helper"

RSpec.describe "Admin generated file event contracts", type: :request do
  let(:admin_user) { create(:user, :internal) }

  describe "GET /admin/generated_file_events" do
    it "matches saved slash paths when the path filter uses Windows separators" do
      sign_in_as(admin_user)
      matched = create_event!(path: "storage/document_files/source.yml", status: :pending)
      unmatched = create_event!(path: "storage/other/source.yml", status: :pending)

      get admin_generated_file_events_path(path: "storage\\document_files")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matched.public_id)
      expect(response.body).not_to include(unmatched.public_id)
    end

    it "shows invalid scheduled date warnings and leaves those filters unapplied" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source.yml", status: :pending)

      get admin_generated_file_events_path(scheduled_from: "invalid-from", scheduled_to: "invalid-to")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.public_id)
      expect(response.body).to include("日時フィルタを確認してください。")
      expect(response.body).to include("実行予定日(開始)「invalid-from」は日時として解釈できないため、この条件は適用していません。")
      expect(response.body).to include("実行予定日(終了)「invalid-to」は日時として解釈できないため、この条件は適用していません。")
    end
  end

  describe "POST /admin/generated_file_events/retry_failed" do
    it "bulk retries the oldest 100 failed events matching the current filters" do
      sign_in_as(admin_user)
      created_at = Time.zone.parse("2026-05-10 00:00:00")
      matched_events = 101.times.map do |i|
        create_event!(
          path: "docs/matched-#{i}.yml",
          status: :failed,
          event_source: "manual_document_upload",
          scheduled_at: created_at + i.minutes,
          created_at: created_at + i.minutes,
          error_message: "boom #{i}",
          processed_at: created_at + i.minutes
        )
      end
      other_source = create_event!(path: "docs/other-source.yml", status: :failed, event_source: "artifact_import", error_message: "boom")
      allow(GeneratedFileEventDispatchJob).to receive(:perform_later)

      post retry_failed_admin_generated_file_events_path(event_source: "manual_document_upload")

      expect(response).to redirect_to(admin_generated_file_events_path(event_source: "manual_document_upload"))
      expect(flash[:notice]).to eq("失敗した生成ファイルイベント 100 件の再投入をキューに投入しました。")
      expect(GeneratedFileEventDispatchJob).to have_received(:perform_later).once

      retried_events = matched_events.first(100).map(&:reload)
      skipped_event = matched_events.last.reload
      expect(retried_events).to all(be_pending)
      expect(retried_events.map(&:error_message)).to all(be_nil)
      expect(retried_events.map(&:processed_at)).to all(be_nil)
      expect(skipped_event).to be_failed
      expect(skipped_event.error_message).to eq("boom 100")
      expect(other_source.reload).to be_failed
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
end
