require "rails_helper"

RSpec.describe "Admin generated file run site build artifact evidence", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def generated_file_run_row(public_id)
    parsed_html.css("tbody tr").find do |row|
      row.at_css(%(a[href*="#{admin_generated_file_runs_path}/#{public_id}"]))
    end
  end

  it "lets admins find a site build artifact run by workflow and artifact metadata" do
    sign_in_as(admin_user)
    run = GeneratedFiles::SiteBuildArtifactRunRecorder.call(
      status: "success",
      artifact: {
        name: "docs-site",
        source_repo: "matsuo-haruhito/docs-portal",
        source_branch: "main",
        source_commit_hash: "abc1234def5678",
        workflow_run_id: 7083,
        workflow_run_attempt: 1,
        manifest_path: "publish/manifest/publish.json"
      },
      manifest: {document_count: 12}
    )
    unrelated = GeneratedFileRun.create!(
      job_id: "regular_generated_file_job",
      status: :completed,
      event_source: "manual_document_upload",
      source_paths: ["docs/source.yml"],
      changed_files: [],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    )

    get admin_generated_file_runs_path(q: "7083")

    expect(response).to have_http_status(:ok)
    expect(generated_file_run_row(run.public_id)).to be_present
    expect(generated_file_run_row(unrelated.public_id)).to be_nil

    get admin_generated_file_runs_path(event_source: "docusaurus_site_build", q: "abc1234")

    expect(response).to have_http_status(:ok)
    expect(generated_file_run_row(run.public_id)).to be_present
    expect(generated_file_run_row(unrelated.public_id)).to be_nil
  end

  it "shows site build artifact metadata through the existing masked detail preview" do
    sign_in_as(admin_user)
    run = GeneratedFiles::SiteBuildArtifactRunRecorder.call(
      status: "success",
      artifact: {
        name: "docs-site",
        source_repo: "matsuo-haruhito/docs-portal",
        source_branch: "main",
        source_commit_hash: "abc1234def5678",
        workflow_run_id: 7083,
        workflow_run_attempt: 1,
        manifest_path: "publish/manifest/publish.json"
      },
      manifest: {documents: [{"path" => "docs/a.md"}]}
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("docusaurus_site_build")
    expect(page_text).to include("docs_site_artifact")
    expect(response.body).to include("docs-site.tar.gz")
    expect(response.body).to include("publish/manifest/publish.json")
    expect(response.body).to include("abc1234def5678")
    expect(response.body).to include("7083")
    expect(response.body).to include("manifest_document_count")
    expect(response.body).not_to include("docs-site artifact full body")
  end
end
