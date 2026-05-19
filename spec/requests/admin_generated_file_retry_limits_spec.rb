require "rails_helper"

RSpec.describe "Admin generated file retry limit notices", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows the generated file run bulk retry limit" do
    sign_in_as(admin_user)
    GeneratedFileRun.create!(
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :failed,
      event_source: "spec",
      source_paths: [],
      changed_files: [],
      generated_paths: [],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    )

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("一括再実行は古い失敗分から最大100件です。")
  end

  it "shows the generated file event bulk retry limit" do
    sign_in_as(admin_user)
    GeneratedFileEvent.create!(
      event_key: GeneratedFileEvent.build_event_key(path: "docs/source.yml", operation: "update", event_source: "spec"),
      path: "docs/source.yml",
      operation: "update",
      event_source: "spec",
      status: :failed,
      metadata: {},
      scheduled_at: 1.minute.ago,
      last_seen_at: Time.current,
      occurrences_count: 1
    )

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("一括再dispatchは古い失敗分から最大100件です。")
  end
end
