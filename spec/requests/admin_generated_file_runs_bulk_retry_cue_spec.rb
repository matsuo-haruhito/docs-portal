require "rails_helper"

RSpec.describe "Admin generated file runs bulk retry cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "shows the current retry target count and the maximum-100 oldest-first cue near the bulk retry action" do
    sign_in_as(admin_user)
    create_run!(status: :failed, job_id: "failed_retry_target_one")
    create_run!(status: :failed, job_id: "failed_retry_target_two")
    create_run!(status: :completed, job_id: "completed_non_target")

    get admin_generated_file_runs_path(status: "failed")

    expect(response).to have_http_status(:ok)
    bulk_retry_form = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(status: "failed")}"]))
    expect(bulk_retry_form).to be_present
    action_panel_text = bulk_retry_form.ancestors("div").first.text.squish
    expect(action_panel_text).to include("失敗分を一括再実行")
    expect(action_panel_text).to include("現在の条件で再実行対象: 2 件")
    expect(action_panel_text).to include("このボタンは現在の絞り込み条件に一致する失敗履歴だけを対象にします。")
    expect(action_panel_text).to include("古い順に最大100件です。")
  end

  it "keeps the no-target cue visible alongside invalid date warnings" do
    sign_in_as(admin_user)
    create_run!(status: :completed, job_id: "completed_only")

    get admin_generated_file_runs_path(status: "failed", created_from: "invalid-date")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("日時フィルタを確認してください。")
    expect(response.body).to include("現在の条件で再実行対象: <strong>0 件</strong>")
    expect(response.body).to include("対象がないため一括再実行できません。")
    button = parsed_html.at_css(%(form[action="#{retry_failed_admin_generated_file_runs_path(status: "failed", created_from: "invalid-date")}"] button))
    expect(button).to be_present
    expect(button["disabled"]).to be_present
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
