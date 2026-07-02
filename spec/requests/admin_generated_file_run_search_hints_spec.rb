require "rails_helper"

RSpec.describe "Admin generated file run search hints", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def search_hint_card
    heading = parsed_html.css("h2").find { _1.text.squish == "一覧 q 検索の手掛かり" }
    heading&.xpath("ancestor::div[contains(concat(' ', normalize-space(@class), ' '), ' rounded-lg ')][1]")&.first
  end

  def search_hint_hrefs
    search_hint_card.css("a[href]").map { _1["href"] }
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
      path:,
      operation:,
      event_source:,
      status: :pending,
      metadata: {},
      scheduled_at: 1.minute.from_now,
      last_seen_at: Time.current,
      occurrences_count: 1
    }
    GeneratedFileEvent.create!(defaults.merge(attributes))
  end

  describe "GET /admin/generated_file_runs/:public_id" do
    it "shows safe short q search hints without exposing raw metadata or private paths as candidates" do
      sign_in_as(admin_user)
      event = create_event!(path: "docs/source-document.yml")
      run = create_run!(
        job_id: "ai_usecase_decision_flow",
        source_paths: ["/home/app/private/token-source.yml", "docs/source-document.yml"],
        changed_files: ["docs/source-document.yml"],
        generated_paths: ["docs/generated-document.md"],
        error_message: "token=raw-secret failed",
        metadata: {
          "generated_file_event_public_ids" => [event.public_id],
          "access_token" => "raw-secret",
          "raw_payload" => "payload-#{'x' * 120}"
        }
      )

      get admin_generated_file_run_path(run.public_id)

      expect(response).to have_http_status(:ok)
      expect(search_hint_card).to be_present
      card_text = search_hint_card.text.squish
      expect(card_text).to include(run.public_id)
      expect(card_text).to include("ai_usecase_decision_flow")
      expect(card_text).to include(event.public_id)
      expect(card_text).to include("source-document.yml")
      expect(card_text).not_to include("raw-secret")
      expect(card_text).not_to include("token-source.yml")
      expect(card_text).not_to include("/home/app/private")
      expect(card_text).not_to include("payload-")
      expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: run.public_id))
      expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: event.public_id))
      expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: "source-document.yml"))
    end

    it "bounds q search hint values to the supported query length" do
      sign_in_as(admin_user)
      long_job_id = "bounded-#{'a' * 120}"
      run = create_run!(job_id: long_job_id)
      expected_hint = long_job_id[0, 100]

      get admin_generated_file_run_path(run.public_id)

      expect(response).to have_http_status(:ok)
      card_text = search_hint_card.text.squish
      expect(card_text).to include(expected_hint)
      expect(card_text).not_to include(long_job_id)
      expect(search_hint_hrefs).to include(admin_generated_file_runs_path(q: expected_hint))
    end
  end
end
