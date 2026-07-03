require "rails_helper"

RSpec.describe "Admin generated file run site build artifact evidence", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows a read-only site build artifact summary from safe metadata" do
    sign_in_as(admin_user)
    run = create_site_build_run!(
      status: :completed,
      metadata: {
        "artifact" => {
          "name" => "docs-site",
          "source_repo" => "matsuo-haruhito/docs-portal",
          "source_branch" => "main",
          "source_commit_hash" => "abc1234def5678",
          "workflow_run_id" => "7083",
          "workflow_run_attempt" => "2",
          "manifest_path" => "publish/manifest/publish.json"
        },
        "read_only_evidence" => true,
        "manifest_document_count" => 12,
        "raw_manifest" => "top-secret-manifest-body",
        "ci_log" => "Bearer abc123token should not be rendered",
        "import_api_request_payload" => {"token" => "super-secret-token"}
      }
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Docusaurus site build artifact evidence")
    expect(page_text).to include("workflow run 7083")
    expect(page_text).to include("attempt 2")
    expect(page_text).to include("source repo matsuo-haruhito/docs-portal")
    expect(page_text).to include("source branch main")
    expect(page_text).to include("source commit abc1234def5678")
    expect(page_text).to include("manifest path publish/manifest/publish.json")
    expect(page_text).to include("artifact docs-site")
    expect(page_text).to include("status cue Rails側metadataで確認可能")
    expect(page_text).to include("manifest documents 12")
    expect(page_text).to include("runbook docs/build-docs workflow確認runbook.md")
    expect(page_text).to include("replay / rebuild / artifact download / preview を実行しません")
    expect(response.body).not_to include("top-secret-manifest-body")
    expect(response.body).not_to include("abc123token")
    expect(response.body).not_to include("super-secret-token")
  end

  it "shows a rebuild cue for failed site build artifact runs" do
    sign_in_as(admin_user)
    run = create_site_build_run!(status: :failed)

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("status cue rebuild優先候補")
  end

  it "does not show the site build artifact summary for unsupported run types" do
    sign_in_as(admin_user)
    run = GeneratedFileRun.create!(
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :completed,
      event_source: "spec",
      source_paths: ["source.yml"],
      changed_files: ["source.yml"],
      generated_paths: ["generated.md"],
      metadata: {
        "artifact" => {"workflow_run_id" => "7083"},
        "read_only_evidence" => true
      },
      started_at: 1.minute.ago,
      finished_at: Time.current
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("Docusaurus site build artifact evidence")
    expect(page_text).not_to include("status cue")
  end

  def create_site_build_run!(attributes = {})
    defaults = {
      job_id: GeneratedFiles::SiteBuildArtifactRunRecorder::JOB_ID,
      generator: GeneratedFiles::SiteBuildArtifactRunRecorder::GENERATOR,
      output_writer: GeneratedFiles::SiteBuildArtifactRunRecorder::OUTPUT_WRITER,
      status: :completed,
      event_source: GeneratedFiles::SiteBuildArtifactRunRecorder::EVENT_SOURCE,
      source_paths: [GeneratedFiles::SiteBuildArtifactRunRecorder::DEFAULT_MANIFEST_PATH],
      changed_files: [],
      generated_paths: ["docs-site.tar.gz", GeneratedFiles::SiteBuildArtifactRunRecorder::DEFAULT_MANIFEST_PATH],
      metadata: {
        "artifact" => {
          "name" => "docs-site",
          "workflow_run_id" => "7083"
        },
        "read_only_evidence" => true
      },
      started_at: Time.zone.parse("2026-06-21 10:00:00"),
      finished_at: Time.zone.parse("2026-06-21 10:03:00")
    }

    GeneratedFileRun.create!(defaults.deep_merge(attributes))
  end
end
