require "rails_helper"

RSpec.describe "Admin generated file event related run return paths", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_hrefs
    parsed_html.css("a[href]").map { _1["href"] }
  end

  it "links related runs back to the event detail while preserving the filtered list return path" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml", status: :failed)
    run = create_run!(
      job_id: "related_job",
      metadata: {"generated_file_event_public_ids" => [event.public_id]}
    )
    filtered_list_path = admin_generated_file_events_path(status: "failed", path: "docs", page: 2, per_page: 25)
    event_return_to_path = admin_generated_file_event_path(event.public_id, return_to: filtered_list_path)

    get admin_generated_file_event_path(event.public_id, return_to: filtered_list_path)

    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(filtered_list_path)
    expect(link_hrefs).to include(admin_generated_file_run_path(run.public_id, return_to: event_return_to_path))

    get admin_generated_file_run_path(run.public_id, return_to: event_return_to_path)

    expect(response).to have_http_status(:ok)
    expect(link_hrefs).to include(event_return_to_path)
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
