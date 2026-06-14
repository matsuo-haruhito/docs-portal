require "rails_helper"

RSpec.describe "Admin generated file run bulk retry summary", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
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

  describe "GET /admin/generated_file_runs" do
    it "shows that bulk retry uses all failed runs when no filters are active" do
      sign_in_as(admin_user)
      create_run!(status: :failed)

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("一括再実行の対象条件")
      expect(page_text).to include("すべての失敗履歴から古い順に最大100件を対象にします。")
      expect(page_text).to include("現在の条件で再実行対象: 1 件")
    end

    it "summarizes active filters near the bulk retry button" do
      sign_in_as(admin_user)
      filters = {
        status: "failed",
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        created_from: "2026-05-10",
        created_to: "2026-05-11",
        q: "timeout"
      }
      create_run!(
        status: :failed,
        generator: "ai_usecase_decision_flow",
        output_writer: "document_version",
        event_source: "manual_document_upload",
        error_message: "timeout while rendering",
        created_at: Time.zone.parse("2026-05-10 12:00:00")
      )

      get admin_generated_file_runs_path(filters)

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("現在の絞り込み条件に一致する失敗履歴から古い順に最大100件を対象にします。")
      expect(page_text).to include("状態: 失敗")
      expect(page_text).to include("ジェネレーター: ai_usecase_decision_flow")
      expect(page_text).to include("出力先: document_version")
      expect(page_text).to include("イベント発生元: 文書手動アップロード")
      expect(page_text).to include("作成日: 2026-05-10〜2026-05-11")
      expect(page_text).to include("検索語: timeout")
      bulk_retry_form = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(filters)}"]))
      expect(bulk_retry_form["data-turbo-confirm"]).to include("現在の条件を確認してから実行してください。")
    end

    it "keeps the summary visible when matching failed runs are absent" do
      sign_in_as(admin_user)
      create_run!(status: :completed)

      get admin_generated_file_runs_path(status: "failed")

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("一括再実行の対象条件")
      expect(page_text).to include("状態: 失敗")
      expect(page_text).to include("対象がないため一括再実行できません。")
      bulk_retry_form = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(status: "failed")}"]))
      expect(bulk_retry_form.at_css("button[disabled]")&.text).to include("失敗分を一括再実行")
    end
  end
end
