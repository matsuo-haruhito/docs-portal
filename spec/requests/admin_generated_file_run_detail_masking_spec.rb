require "rails_helper"

RSpec.describe "Admin generated file run detail masking", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "masks secret-like diagnostics while preserving retry and event context" do
    sign_in_as(admin_user)
    related_event = create_event!(path: "docs/source.yml")
    original_run = create_run!(job_id: "retry_parent_job")
    run = create_run!(
      job_id: "ai_usecase_decision_flow",
      status: :failed,
      error_message: "Authorization: Bearer abc123 failed token=super-secret-token-1959 at /Users/alice/customer/source.yml",
      metadata: {
        "generated_file_event_public_ids" => [related_event.public_id],
        "retry_of_generated_file_run_public_id" => original_run.public_id,
        "retry_requested_at" => "2026-06-04T07:00:00Z",
        "clientState" => "raw-client-state-1959",
        "X-Goog-Channel-Token" => "channel-token-1959",
        "headers" => {"authorization" => "Bearer nested-secret-1959"},
        "attempts" => [
          {"note" => "job ok", "path" => "/home/alice/build.log"}
        ]
      }
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(related_event.public_id)
    expect(response.body).to include(original_run.public_id)
    expect(response.body).to include("2026-06-04T07:00:00Z")
    expect(response.body).to include("job ok")
    expect(response.body).to include("[FILTERED]")
    expect(response.body).not_to include("abc123")
    expect(response.body).not_to include("super-secret-token-1959")
    expect(response.body).not_to include("raw-client-state-1959")
    expect(response.body).not_to include("channel-token-1959")
    expect(response.body).not_to include("nested-secret-1959")
    expect(response.body).not_to include("/Users/alice/customer/source.yml")
    expect(response.body).not_to include("/home/alice/build.log")
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
