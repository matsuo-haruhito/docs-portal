require "rails_helper"

RSpec.describe "Admin generated file source labels", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def summary_value_for(label)
    term = parsed_html.css("dt").find { |node| node.text.strip == label }
    term&.parent&.at_css("dd")&.text.to_s.squish
  end

  describe "GET /admin/generated_file_events" do
    it "shows localized source labels in the index" do
      sign_in_as(admin_user)
      create_event!(path: "docs/manual.md", event_source: "manual_document_upload")
      create_event!(path: "docs/imported.md", event_source: "artifact_import")

      get admin_generated_file_events_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("文書手動アップロード")
      expect(response.body).to include("ZIP / APIインポート")
      expect(response.body).not_to include("manual_document_upload")
      expect(response.body).not_to include("artifact_import")
    end
  end

  describe "GET /admin/generated_file_events/:public_id" do
    it "shows the localized source label in the summary" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/retry.md", event_source: "generated_file_run_bulk_retry")

      get admin_generated_file_event_path(event.public_id)

      expect(response).to have_http_status(:ok)
      expect(summary_value_for("発生元")).to include("生成ジョブからの一括再実行")
      expect(summary_value_for("発生元")).to include("一括再実行")
      expect(summary_value_for("発生元")).not_to include("generated_file_run_bulk_retry")
    end
  end

  describe "GET /admin/generated_file_runs" do
    it "shows localized source labels in the index" do
      sign_in_as(admin_user)
      create_run!(job_id: "manual_job", event_source: "manual_document_upload")
      create_run!(job_id: "retry_job", event_source: "generated_file_run_retry")

      get admin_generated_file_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("文書手動アップロード")
      expect(response.body).to include("生成ジョブからの再実行")
      expect(response.body).not_to include("manual_document_upload")
      expect(response.body).not_to include("generated_file_run_retry")
    end
  end

  describe "GET /admin/generated_file_runs/:public_id" do
    it "shows the localized source label in the summary" do
      sign_in_as(admin_user)
      run = create_run!(job_id: "retry_job", event_source: "generated_file_run_retry")

      get admin_generated_file_run_path(run.public_id)

      expect(response).to have_http_status(:ok)
      expect(summary_value_for("発生元")).to include("生成ジョブからの再実行")
      expect(summary_value_for("発生元")).to include("再実行")
      expect(summary_value_for("発生元")).not_to include("generated_file_run_retry")
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
