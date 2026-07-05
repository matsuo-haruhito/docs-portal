require "rails_helper"

RSpec.describe "Admin generated file run detail link accessibility", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "adds short row context to each action-column detail link" do
    sign_in_as(admin_user)
    failed_run = create_run!(
      job_id: "private_job_identifier",
      generator: "ai_usecase_decision_flow",
      output_writer: "document_version",
      status: :failed,
      error_message: "token-like raw payload should stay out",
      source_paths: ["docs/private/source.yml"],
      metadata: {"secret" => "should stay out"}
    )
    completed_run = create_run!(
      job_id: "fallback_job_identifier",
      generator: "",
      output_writer: "filesystem",
      status: :completed,
      error_message: "metadata should stay out",
      generated_paths: ["generated/private.md"]
    )

    get admin_generated_file_runs_path(page: 1)

    expect(response).to have_http_status(:ok)
    detail_links = parsed_html.css('a[href]').select { |link| link.text.squish == "詳細" }
    labels = detail_links.map { |link| link["aria-label"] }

    expect(labels).to contain_exactly(
      a_string_including(failed_run.public_id, "ai_usecase_decision_flow"),
      a_string_including(completed_run.public_id, "filesystem")
    )
    expect(labels.uniq.size).to eq(labels.size)
    expect(labels).to all(include("の詳細を開く"))
    expect(labels.join(" ")).not_to include("docs/private/source.yml")
    expect(labels.join(" ")).not_to include("generated/private.md")
    expect(labels.join(" ")).not_to include("token-like")
    expect(labels.join(" ")).not_to include("secret")
    detail_links.each do |link|
      expect(link["title"]).to eq(link["aria-label"])
      expect(link["href"]).to include("return_to=")
    end
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
