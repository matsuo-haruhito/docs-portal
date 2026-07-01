require "rails_helper"
require "fileutils"

RSpec.describe "API internal artifact imports", type: :request do
  let(:token) { "secret-token" }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:artifact_root) { import_root.join("artifact-set") }
  let(:manifest_path) { artifact_root.join("manifest.json") }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:endpoint) { "/api/internal/artifact_imports" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return("importer@example.com")

    FileUtils.mkdir_p(artifact_root.join("attachments"))
    create(:user, :internal, email_address: "importer@example.com")
  end

  after do
    FileUtils.rm_rf(import_root)
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "imports-spec"))
  end

  it "rejects import paths outside the allowed import root" do
    outside_manifest = Rails.root.join("tmp", "outside-manifest.json")
    begin
      FileUtils.mkdir_p(outside_manifest.dirname)
      File.write(outside_manifest, { source_repo: "repo", source_branch: "main", source_commit_hash: "abc", documents: [] }.to_json)

      post endpoint, params: {
        artifact_root: outside_manifest.dirname.to_s,
        manifest_path: outside_manifest.to_s
      }, headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to include("allowed import root")
    ensure
      FileUtils.rm_f(outside_manifest)
    end
  end

  it "rejects manifest paths that escape the artifact root without leaking the raw path" do
    escaped_manifest = import_root.join("escaped-manifest.json")
    File.write(escaped_manifest, { source_repo: "repo", source_branch: "main", source_commit_hash: "abc", documents: [] }.to_json)

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: escaped_manifest.to_s
    }, headers: headers

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to include("artifact root")
    expect(response.parsed_body["error"]).not_to include(escaped_manifest.to_s)
  end

  it "rejects invalid storage_key values" do
    project = create(:project, code: "PJIMPORT", name: "Import Project")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc",
        documents: [
          {
            project_code: project.code,
            slug: "imported-doc",
            title: "Imported Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            files: [
              {
                file_name: "bad.txt",
                content_type: "text/plain",
                storage_key: "../bad.txt",
                file_size: 4
              }
            ]
          }
        ]
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("storage_key")
  end

  it "accepts a valid import path within the allowed root" do
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc",
        documents: []
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
    expect(response.parsed_body["import_dry_run_id"]).to be_nil

    publish_job = PublishJob.find(response.parsed_body.fetch("publish_job_id"))
    expect(publish_job.log_message).to include("Imported successfully")
    expect(publish_job.log_message).to include("dry_run=not_provided direct_artifact_apply=true")
  end

  it "notifies generated file events after importing documents" do
    project = create(:project, code: "PJIMPORTNOTIFY", name: "Import Notify Project")
    allow(GeneratedFileChangeEventJob).to receive(:perform_later)
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "commit-notify",
        documents: [
          {
            project_code: project.code,
            slug: "notify-doc",
            title: "Notify Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            source_relative_path: "docs/notify-doc.md"
          }
        ]
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers: headers

    expect(response).to have_http_status(:created)
    publish_job = PublishJob.find(response.parsed_body.fetch("publish_job_id"))
    actor = User.find_by!(email_address: "importer@example.com")
    expect(GeneratedFileChangeEventJob).to have_received(:perform_later).with(
      file_events: [{path: "docs/notify-doc.md", operation: "create"}],
      event_source: "artifact_import",
      metadata: hash_including(
        publish_job_id: publish_job.id,
        actor_id: actor.id,
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "commit-notify"
      )
    )
  end

  it "returns and saves a dry-run result in validate_only mode" do
    project = create(:project, code: "PJDRYRUN", name: "Dry Run Project")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc123",
        documents: [
          {
            project_code: project.code,
            slug: "new-doc",
            title: "New Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            source_relative_path: "docs/new-doc.md"
          }
        ]
      }.to_json
    )

    expect do
      post endpoint, params: {
        artifact_root: artifact_root.to_s,
        manifest_path: manifest_path.to_s,
        validate_only: true
      }, headers: headers
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["valid"]).to eq(true)
    expect(response.parsed_body["status"]).to eq("analyzed")
    expect(response.parsed_body["summary"]["create_count"]).to eq(1)
    expect(response.parsed_body["dry_run_id"]).to be_present
    expect(response.parsed_body).to have_key("expires_at")

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body["dry_run_id"])
    expect(dry_run.git_push?).to eq(true)
    expect(dry_run.analyzed?).to eq(true)
    expect(dry_run.project).to eq(project)
    expect(dry_run.source_commit_hash).to eq("abc123")
    expect(dry_run.result_json["projects"].size).to eq(1)
  end

  it "imports using a confirmed dry-run id when the source commit matches" do
    project = create(:project, code: "PJCONFIRM", name: "Confirmed Dry Run Project")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "commit-1",
        documents: [
          {
            project_code: project.code,
            slug: "confirmed-doc",
            title: "Confirmed Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            source_relative_path: "docs/confirmed-doc.md"
          }
        ]
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s,
      validate_only: true
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s,
      import_dry_run_id: dry_run_id
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
    expect(response.parsed_body["import_dry_run_id"]).to eq(dry_run_id)

    publish_job = PublishJob.find(response.parsed_body.fetch("publish_job_id"))
    expect(publish_job.log_message).to include("dry_run=#{dry_run_id}")
    expect(publish_job.log_message).not_to include("dry_run=not_provided")

    dry_run = ImportDryRun.find_by!(public_id: dry_run_id)
    expect(dry_run.confirmed?).to eq(true)
    expect(dry_run.confirmed_by.email_address).to eq("importer@example.com")
    expect(dry_run.confirmed_at).to be_present
  end

  it "rejects non git-push dry-run ids for artifact apply" do
    project = create(:project, code: "PJMODE", name: "Mode Dry Run Project")
    actor = User.find_by!(email_address: "importer@example.com")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "commit-1",
        documents: []
      }.to_json
    )

    %i[zip manual_upload].each do |import_mode|
      dry_run = ImportDryRun.create!(
        import_mode: import_mode,
        status: :analyzed,
        project: project,
        created_by: actor,
        source_commit_hash: "commit-1",
        summary_json: { create_count: 0, update_count: 0, unchanged_count: 0, error_count: 0 },
        result_json: { projects: [] },
        warnings_json: [],
        errors_json: []
      )

      expect do
        post endpoint, params: {
          artifact_root: artifact_root.to_s,
          manifest_path: manifest_path.to_s,
          import_dry_run_id: dry_run.public_id
        }, headers: headers
      end.not_to change(PublishJob, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("git_push")
      expect(dry_run.reload.analyzed?).to eq(true)
    end
  end

  it "rejects a confirmed dry-run when the manifest commit changed" do
    project = create(:project, code: "PJMISMATCH", name: "Mismatched Dry Run Project")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "commit-1",
        documents: [
          {
            project_code: project.code,
            slug: "mismatch-doc",
            title: "Mismatch Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            source_relative_path: "docs/mismatch-doc.md"
          }
        ]
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s,
      validate_only: true
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")

    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "commit-2",
        documents: []
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s,
      import_dry_run_id: dry_run_id
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("source_commit_hash")
    expect(ImportDryRun.find_by!(public_id: dry_run_id).analyzed?).to eq(true)
  end

  it "rejects imports when DOC_IMPORT_ACTOR_EMAIL is not configured" do
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return(nil)
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc",
        documents: []
      }.to_json
    )

    post endpoint, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("DOC_IMPORT_ACTOR_EMAIL")
  end
end
