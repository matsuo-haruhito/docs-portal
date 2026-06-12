require "rails_helper"

RSpec.describe "Admin generated file run bulk retry contract", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def bulk_retry_form
    parsed_html.css("form[action]").find do |form|
      URI.parse(form["action"]).path == retry_failed_admin_generated_file_runs_path
    end
  end

  describe "GET /admin/generated_file_runs" do
    it "shows the bulk retry action disabled for non-failed status filters" do
      sign_in_as(admin_user)
      failed_run = create_run!(job_id: "same_job", generator: "contract_generator", status: :failed)
      completed_run = create_run!(job_id: "same_job", generator: "contract_generator", status: :completed)

      get admin_generated_file_runs_path(status: "completed", generator: "contract_generator")

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("現在の条件で再実行対象: 0 件")
      expect(page_text).to include("対象がないため一括再実行できません。")
      expect(bulk_retry_form.at_css("button[disabled]")&.text).to include("失敗分を一括再実行")
      expect(response.body).to include(completed_run.public_id)
      expect(response.body).not_to include(failed_run.public_id)
    end

    it "shows the same 100-run ceiling used by bulk retry enqueue" do
      sign_in_as(admin_user)
      101.times do |i|
        create_run!(
          job_id: "bulk_retry_ui_match_#{i}",
          generator: "bulk_retry_contract",
          status: :failed,
          created_at: Time.zone.parse("2026-05-10 00:00:00") + i.minutes
        )
      end
      create_run!(job_id: "bulk_retry_ui_completed", generator: "bulk_retry_contract", status: :completed)

      get admin_generated_file_runs_path(status: "failed", generator: "bulk_retry_contract")

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("現在の条件で再実行対象: 100 件")
      expect(bulk_retry_form["data-turbo-confirm"]).to include("現在の条件に一致する失敗履歴 100 件")
      expect(bulk_retry_form["data-turbo-confirm"]).to include("古い順に最大100件")
      expect(page_text).to include("このボタンは現在の絞り込み条件に一致する失敗履歴だけを対象にします。古い順に最大100件です。")
    end

    it "keeps bulk retry counts aligned with valid filters when date filters warn" do
      sign_in_as(admin_user)
      before_range = create_run!(job_id: "bulk_retry_before_range", generator: "bulk_retry_contract", status: :failed, created_at: Time.zone.parse("2026-05-09 12:00:00"))
      inside_range = create_run!(job_id: "bulk_retry_inside_range", generator: "bulk_retry_contract", status: :failed, created_at: Time.zone.parse("2026-05-10 12:00:00"))
      after_range = create_run!(job_id: "bulk_retry_after_range", generator: "bulk_retry_contract", status: :failed, created_at: Time.zone.parse("2026-05-12 12:00:00"))
      create_run!(job_id: "bulk_retry_completed_range", generator: "bulk_retry_contract", status: :completed, created_at: Time.zone.parse("2026-05-10 12:00:00"))

      get admin_generated_file_runs_path(
        status: "failed",
        generator: "bulk_retry_contract",
        created_from: "not-a-date",
        created_to: "2026-05-10"
      )

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("作成日(開始)「not-a-date」は日時として解釈できないため、この条件は適用していません。")
      expect(page_text).to include("現在の条件で再実行対象: 2 件")
      expect(response.body).to include(before_range.public_id)
      expect(response.body).to include(inside_range.public_id)
      expect(response.body).not_to include(after_range.public_id)
    end
  end

  describe "POST /admin/generated_file_runs/retry_failed" do
    it "uses the same valid filters and ignored invalid date filters as the list count" do
      sign_in_as(admin_user)
      before_range = create_run!(job_id: "bulk_retry_before_range", generator: "bulk_retry_contract", status: :failed, changed_files: ["before.yml"], created_at: Time.zone.parse("2026-05-09 12:00:00"))
      inside_range = create_run!(job_id: "bulk_retry_inside_range", generator: "bulk_retry_contract", status: :failed, changed_files: ["inside.yml"], created_at: Time.zone.parse("2026-05-10 12:00:00"))
      after_range = create_run!(job_id: "bulk_retry_after_range", generator: "bulk_retry_contract", status: :failed, changed_files: ["after.yml"], created_at: Time.zone.parse("2026-05-12 12:00:00"))
      create_run!(job_id: "bulk_retry_completed_range", generator: "bulk_retry_contract", status: :completed, changed_files: ["completed.yml"], created_at: Time.zone.parse("2026-05-10 12:00:00"))
      allow(GeneratedFileJob).to receive(:perform_later)

      filters = {
        status: "failed",
        generator: "bulk_retry_contract",
        created_from: "not-a-date",
        created_to: "2026-05-10"
      }

      post retry_failed_admin_generated_file_runs_path(filters)

      expect(response).to redirect_to(admin_generated_file_runs_path(filters))
      expect(GeneratedFileJob).to have_received(:perform_later).exactly(2).times
      expect(GeneratedFileJob).to have_received(:perform_later).with(
        changed_files: ["before.yml"],
        job_ids: ["bulk_retry_before_range"],
        event_source: "generated_file_run_bulk_retry",
        metadata: hash_including(
          "retry_of_generated_file_run_public_id" => before_range.public_id,
          "retry_requested_by_user_id" => admin_user.id,
          "bulk_retry" => true
        )
      )
      expect(GeneratedFileJob).to have_received(:perform_later).with(
        changed_files: ["inside.yml"],
        job_ids: ["bulk_retry_inside_range"],
        event_source: "generated_file_run_bulk_retry",
        metadata: hash_including(
          "retry_of_generated_file_run_public_id" => inside_range.public_id,
          "retry_requested_by_user_id" => admin_user.id,
          "bulk_retry" => true
        )
      )
      expect(GeneratedFileJob).not_to have_received(:perform_later).with(
        changed_files: ["after.yml"],
        job_ids: ["bulk_retry_after_range"],
        event_source: "generated_file_run_bulk_retry",
        metadata: anything
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
end
