require "rails_helper"

RSpec.describe "Admin generated file run search hints", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def search_hint_card
    parsed_html.css("div").find do |node|
      node.at_css("h2")&.text&.squish == "一覧 q 検索の手掛かり"
    end
  end

  def search_hint_text
    search_hint_card&.text&.squish.to_s
  end

  def search_hint_hrefs
    search_hint_card.css("a[href]").map { _1["href"] }
  end

  it "shows bounded q search hint links without exposing sensitive values" do
    sign_in_as(admin_user)
    event = create_event!(path: "docs/source.yml")
    run = create_run!(
      job_id: "ai_usecase_decision_flow_document_version",
      source_paths: ["/home/app/private/token-source.yml", "docs/imports/source-document.yml"],
      changed_files: ["docs/changes/changed-document.yml"],
      generated_paths: ["generated/site-output.md"],
      error_message: "token=raw-secret Renderer timeout at /home/app/private/source.yml",
      metadata: {
        "generated_file_event_public_ids" => [event.public_id],
        "access_token" => "raw-secret-token",
        "raw_payload" => "payload-#{"x" * 120}"
      }
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(search_hint_card).to be_present
    expect(search_hint_text).to include("実行ID", run.public_id)
    expect(search_hint_text).to include("ジョブID", "ai_usecase_decision_flow_document_version")
    expect(search_hint_text).to include("関連イベントID", event.public_id)
    expect(search_hint_text).to include("パス断片", "source-document.yml")
    expect(search_hint_text).not_to include("raw-secret")
    expect(search_hint_text).not_to include("token-source.yml")
    expect(search_hint_text).not_to include("/home/app/private")
    expect(search_hint_text).not_to include("payload-")
    expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: run.public_id))
    expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: event.public_id))
    expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: "source-document.yml"))
  end

  it "truncates search hint values to the q search limit" do
    sign_in_as(admin_user)
    bounded_job_id = "bounded-#{"a" * 120}"
    run = create_run!(job_id: bounded_job_id)
    expected_hint = bounded_job_id.first(Admin::GeneratedFileRunsController::QUERY_MAX_LENGTH)

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(search_hint_text).to include(expected_hint)
    expect(search_hint_text).not_to include(bounded_job_id)
    expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: expected_hint))
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
