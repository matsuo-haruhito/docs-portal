require "rails_helper"

RSpec.describe "Admin generated file run retry return context", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
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

  it "preserves the filtered list path in row retry forms" do
    sign_in_as(admin_user)
    run = create_run!(job_id: "ai_usecase_decision_flow", generator: "ai_usecase_decision_flow", status: :failed, created_at: 1.day.ago)
    25.times do |i|
      create_run!(job_id: "newer_job_#{i}", generator: "ai_usecase_decision_flow", status: :failed)
    end
    return_to_path = admin_generated_file_runs_path(status: "failed", generator: "ai_usecase_decision_flow", page: 2, per_page: 25)

    get return_to_path

    expect(response).to have_http_status(:ok)
    retry_form = parsed_html.at_css(%(form[action="#{retry_run_admin_generated_file_run_path(run.public_id, return_to: return_to_path)}"]))
    expect(retry_form).to be_present
    expect(retry_form.at_css("button")&.text).to include("再実行")
  end
end
