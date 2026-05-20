require "rails_helper"
require "fileutils"

RSpec.describe "API internal upload imports generated file events", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:artifact_root) { import_root.join("upload-import-event-spec") }
  let(:manifest_path) { artifact_root.join("manifest.json") }
  let(:actor_email) { "importer@example.com" }
  let(:actor) { create(:user, :internal, email_address: actor_email) }
  let(:project) { create(:project, code: "PJUPLOADIMPORT", name: "Upload Import Project") }

  before do
    actor
    project
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return(actor_email)
    FileUtils.mkdir_p(artifact_root.join("attachments"))
    write_manifest!(source_commit_hash: "commit-upload-event")
  end

  after do
    FileUtils.rm_rf(import_root)
  end

  it "notifies generated file events when executing a confirmed ZIP upload dry-run" do
    dry_run = create_dry_run!(import_mode: :zip)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later)

    post "/api/internal/zip_uploads", params: {
      import_dry_run_id: dry_run.public_id
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
    expect(GeneratedFileChangeEventJob).to have_received(:perform_later).with(
      file_events: [{path: "docs/zip-upload-source.md", operation: "create"}],
      event_source: "artifact_import",
      metadata: hash_including(
        actor_id: actor.id,
        source_repo: "upload_import_spec",
        source_branch: "zip_upload",
        source_commit_hash: "commit-upload-event"
      )
    )
    expect(dry_run.reload).to be_confirmed
  end

  it "notifies generated file events when executing a confirmed file upload dry-run" do
    dry_run = create_dry_run!(import_mode: :manual_upload)
    allow(GeneratedFileChangeEventJob).to receive(:perform_later)

    post "/api/internal/file_uploads", params: {
      import_dry_run_id: dry_run.public_id
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
    expect(GeneratedFileChangeEventJob).to have_received(:perform_later).with(
      file_events: [{path: "docs/zip-upload-source.md", operation: "create"}],
      event_source: "artifact_import",
      metadata: hash_including(
        actor_id: actor.id,
        source_repo: "upload_import_spec",
        source_branch: "zip_upload",
        source_commit_hash: "commit-upload-event"
      )
    )
    expect(dry_run.reload).to be_confirmed
  end

  def write_manifest!(source_commit_hash:)
    File.write(
      manifest_path,
      {
        source_repo: "upload_import_spec",
        source_branch: "zip_upload",
        source_commit_hash: source_commit_hash,
        documents: [
          {
            project_code: project.code,
            slug: "upload-event-doc",
            title: "Upload Event Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            source_relative_path: "docs/zip-upload-source.md"
          }
        ]
      }.to_json
    )
  end

  def create_dry_run!(import_mode:)
    ImportDryRun.create!(
      import_mode: import_mode,
      project: project,
      created_by: actor,
      source_commit_hash: "commit-upload-event",
      summary_json: {"create_count" => 1},
      result_json: {
        "artifact_root" => artifact_root.to_s,
        "manifest_path" => manifest_path.to_s
      },
      warnings_json: [],
      errors_json: [],
      status: :analyzed
    )
  end
end
