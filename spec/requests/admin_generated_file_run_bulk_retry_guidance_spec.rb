require "rails_helper"

RSpec.describe "Admin generated file run bulk retry guidance", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  describe "GET /admin/generated_file_runs" do
    it "shows the current filtered bulk retry target count before retrying" do
      sign_in_as(admin_user)
      create_run!(job_id: "matched_old", generator: "target_generator", status: :failed, created_at: Time.zone.parse("2026-05-10 10:00:00"))
      create_run!(job_id: "matched_new", generator: "target_generator", status: :failed, created_at: Time.zone.parse("2026-05-11 10:00:00"))
      create_run!(job_id: "completed", generator: "target_generator", status: :completed)
      create_run!(job_id: "other", generator: "other_generator", status: :failed)

      get admin_generated_file_runs_path(generator: "target_generator")

      expect(response).to have_http_status(:ok)
      expect(parsed_html.text).to include("現在の条件で再実行対象: 2 件")
      expect(parsed_html.text).to include("一括再実行は現在条件に一致する古い失敗分から最大100件です。")
      button = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(generator: "target_generator")}"] button))
      expect(button).to be_present
      expect(button["disabled"]).to be_nil
    end

    it "disables bulk retry when the current filters have no failed targets" do
      sign_in_as(admin_user)
      create_run!(job_id: "completed", generator: "target_generator", status: :completed)
      create_run!(job_id: "other", generator: "other_generator", status: :failed)

      get admin_generated_file_runs_path(generator: "target_generator")

      expect(response).to have_http_status(:ok)
      expect(parsed_html.text).to include("現在の条件で再実行対象: 0 件")
      expect(parsed_html.text).to include("対象がないため一括再実行できません。")
      button = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(generator: "target_generator")}"] button))
      expect(button).to be_present
      expect(button["disabled"]).to eq("disabled")
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