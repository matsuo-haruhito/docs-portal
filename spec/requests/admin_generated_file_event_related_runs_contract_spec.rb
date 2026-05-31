require "rails_helper"

RSpec.describe "Admin generated file event related run contract", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows up to ten related runs from the latest 200 generated file runs" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml")
    base_time = Time.zone.parse("2026-05-10 00:00:00")
    outside_scan = create_run!(
      job_id: "outside-scan-job",
      created_at: base_time,
      metadata: {"generated_file_event_public_ids" => [event.public_id]}
    )

    200.times do |index|
      create_run!(
        job_id: "unrelated-job-#{index}",
        created_at: base_time + (index + 1).minutes,
        metadata: {"generated_file_event_public_ids" => ["gf_evt_other_#{index}"]}
      )
    end

    related_runs = 12.times.map do |index|
      create_run!(
        job_id: "related-job-#{index}",
        created_at: base_time + (300 + index).minutes,
        metadata: {"generated_file_event_public_ids" => [event.public_id]}
      )
    end

    get admin_generated_file_event_path(event.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("最新200件の実行履歴から、このイベントに関連する最大10件を表示します。")
    related_runs.last(10).reverse_each do |run|
      expect(response.body).to include(admin_generated_file_run_path(run.public_id))
    end
    related_runs.first(2).each do |run|
      expect(response.body).not_to include(admin_generated_file_run_path(run.public_id))
    end
    expect(response.body).not_to include(admin_generated_file_run_path(outside_scan.public_id))
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
