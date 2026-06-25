require "rails_helper"

RSpec.describe "Admin generated file detail action cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "clarifies that the run detail retry action targets the current run" do
    sign_in_as(admin_user)
    run = create_run!(job_id: "ai_usecase_decision_flow", status: :failed)

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    retry_button = parsed_html.at_css(%(form[action*="#{retry_run_admin_generated_file_run_path(run.public_id)}"] button[type="submit"]))
    expect(retry_button).to be_present
    expect(retry_button.text.squish).to eq("この実行を再実行")
    expect(retry_button["aria-label"]).to eq("#{run.public_id} を再実行キューに投入")
    expect(retry_button["title"]).to eq("#{run.public_id} を再実行キューに投入")
  end

  it "clarifies that the event detail retry action targets the current event" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml", status: :failed)

    get admin_generated_file_event_path(event.public_id)

    expect(response).to have_http_status(:ok)
    retry_button = parsed_html.at_css(%(form[action*="#{retry_dispatch_admin_generated_file_event_path(event.public_id)}"] button[type="submit"]))
    expect(retry_button).to be_present
    expect(retry_button.text.squish).to eq("このイベントを再投入")
    expect(retry_button["aria-label"]).to eq("#{event.public_id} を再投入キューに投入")
    expect(retry_button["title"]).to eq("#{event.public_id} を再投入キューに投入")
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
