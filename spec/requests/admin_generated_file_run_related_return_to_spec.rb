require "rails_helper"

RSpec.describe "Admin generated file run related return paths", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
  end

  it "passes the filtered run list return path to related event and retry run links" do
    sign_in_as(admin_user)
    related_event = create_event!(path: "docs/source.yml")
    original_run = create_run!(job_id: "original_retry_parent")
    retry_child_run = create_run!(
      job_id: "ai_usecase_decision_flow",
      status: :completed,
      event_source: "generated_file_run_bulk_retry",
      metadata: {"retry_of_generated_file_run_public_id" => original_run.public_id}
    )
    run = create_run!(
      job_id: "ai_usecase_decision_flow",
      status: :failed,
      event_source: "generated_file_run_retry",
      metadata: {
        "generated_file_event_public_ids" => [related_event.public_id],
        "retry_of_generated_file_run_public_id" => original_run.public_id
      }
    )
    return_to_path = admin_generated_file_runs_path(
      status: "failed",
      generator: "sample_generator",
      q: "timeout",
      page: 2,
      per_page: 25
    )

    get admin_generated_file_run_path(run.public_id, return_to: return_to_path)

    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(admin_generated_file_event_path(related_event.public_id, return_to: return_to_path))
    expect(link_hrefs).to include(admin_generated_file_run_path(original_run.public_id, return_to: return_to_path))
    expect(link_hrefs).to include(admin_generated_file_run_path(retry_child_run.public_id, return_to: return_to_path))
  end

  it "does not propagate an unsafe return path to related links" do
    sign_in_as(admin_user)
    related_event = create_event!(path: "docs/source.yml")
    original_run = create_run!(job_id: "original_retry_parent")
    retry_child_run = create_run!(
      job_id: "ai_usecase_decision_flow",
      status: :completed,
      event_source: "generated_file_run_retry",
      metadata: {"retry_of_generated_file_run_public_id" => original_run.public_id}
    )
    run = create_run!(
      job_id: "ai_usecase_decision_flow",
      status: :failed,
      metadata: {
        "generated_file_event_public_ids" => [related_event.public_id],
        "retry_of_generated_file_run_public_id" => original_run.public_id
      }
    )
    fallback_path = admin_generated_file_runs_path

    get admin_generated_file_run_path(run.public_id, return_to: "//example.com")

    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(fallback_path)
    expect(link_hrefs).to include(admin_generated_file_event_path(related_event.public_id, return_to: fallback_path))
    expect(link_hrefs).to include(admin_generated_file_run_path(original_run.public_id, return_to: fallback_path))
    expect(link_hrefs).to include(admin_generated_file_run_path(retry_child_run.public_id, return_to: fallback_path))
    expect(link_hrefs.join("\n")).not_to include("//example.com")
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
