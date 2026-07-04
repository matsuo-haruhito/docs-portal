require "rails_helper"
require "digest"
require "tempfile"

RSpec.describe "API internal upload apply maintenance", type: :request do
  let(:token) { "test-import-token" }
  let!(:project) { create(:project) }
  let!(:actor) { create(:user, :internal, email_address: "importer@example.com") }

  around do |example|
    previous_token = ENV["DOC_IMPORT_TOKEN"]
    previous_actor = ENV["DOC_IMPORT_ACTOR_EMAIL"]
    previous_maintenance = ENV["READ_ONLY_MAINTENANCE"]

    ENV["DOC_IMPORT_TOKEN"] = token
    ENV["DOC_IMPORT_ACTOR_EMAIL"] = actor.email_address

    example.run
  ensure
    ENV["DOC_IMPORT_TOKEN"] = previous_token
    ENV["DOC_IMPORT_ACTOR_EMAIL"] = previous_actor
    ENV["READ_ONLY_MAINTENANCE"] = previous_maintenance
  end

  describe "POST /api/internal/artifact_imports" do
    it "stops direct apply during read-only maintenance before importer execution" do
      ENV["READ_ONLY_MAINTENANCE"] = "true"

      expect(DocumentImporter).not_to receive(:new)

      post "/api/internal/artifact_imports",
        params: artifact_apply_params,
        headers: auth_headers

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body.fetch("error")).to include("internal upload apply requests are paused")
    end

    it "stops confirmed dry-run apply without confirming the dry-run" do
      ENV["READ_ONLY_MAINTENANCE"] = "true"
      dry_run = create_import_dry_run(import_mode: :git_push)

      expect(DocumentImporter).not_to receive(:new)

      post "/api/internal/artifact_imports",
        params: artifact_apply_params.merge(import_dry_run_id: dry_run.public_id),
        headers: auth_headers

      expect(response).to have_http_status(:service_unavailable)
      expect(dry_run.reload).to be_analyzed
      expect(dry_run.confirmed_by).to be_nil
      expect(dry_run.confirmed_at).to be_nil
    end

    it "keeps direct apply behavior when read-only maintenance is disabled" do
      ENV["READ_ONLY_MAINTENANCE"] = "false"
      publish_job = create_publish_job
      importer = instance_double(DocumentImporter, call: publish_job, manifest: { "source_commit_hash" => "commit-1" })

      expect(DocumentImporter).to receive(:new).and_return(importer)

      post "/api/internal/artifact_imports",
        params: artifact_apply_params,
        headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "publish_job_id" => publish_job.id,
        "status" => "imported",
        "import_dry_run_id" => nil
      )
      expect(publish_job.reload.log_message).to include("direct_artifact_apply=true")
    end
  end

  describe "POST /api/internal/zip_uploads" do
    it "stops ZIP dry-run apply without confirming the dry-run" do
      ENV["READ_ONLY_MAINTENANCE"] = "true"
      dry_run = create_import_dry_run(import_mode: :zip)

      expect(DocumentImporter).not_to receive(:new)

      post "/api/internal/zip_uploads",
        params: { import_dry_run_id: dry_run.public_id },
        headers: auth_headers

      expect(response).to have_http_status(:service_unavailable)
      expect(dry_run.reload).to be_analyzed
      expect(dry_run.confirmed_by).to be_nil
      expect(dry_run.confirmed_at).to be_nil
    end

    it "keeps ZIP dry-run apply behavior when read-only maintenance is disabled" do
      ENV["READ_ONLY_MAINTENANCE"] = "false"
      dry_run = create_import_dry_run(import_mode: :zip)
      publish_job = create_publish_job
      importer = instance_double(DocumentImporter, call: publish_job)

      expect(DocumentImporter).to receive(:new).and_return(importer)

      post "/api/internal/zip_uploads",
        params: { import_dry_run_id: dry_run.public_id },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "publish_job_id" => publish_job.id,
        "status" => "imported",
        "import_dry_run_id" => dry_run.public_id
      )
      expect(dry_run.reload).to be_confirmed
      expect(dry_run.confirmed_by).to eq(actor)
      expect(dry_run.confirmed_at).to be_present
      expect(publish_job.reload.log_message).to include("dry_run=#{dry_run.public_id}")
    end
  end

  describe "POST /api/internal/file_uploads" do
    it "stops manual file dry-run apply without confirming the dry-run" do
      ENV["READ_ONLY_MAINTENANCE"] = "true"
      dry_run = create_import_dry_run(import_mode: :manual_upload)

      expect(DocumentImporter).not_to receive(:new)

      post "/api/internal/file_uploads",
        params: { import_dry_run_id: dry_run.public_id },
        headers: auth_headers

      expect(response).to have_http_status(:service_unavailable)
      expect(dry_run.reload).to be_analyzed
      expect(dry_run.confirmed_by).to be_nil
      expect(dry_run.confirmed_at).to be_nil
    end

    it "keeps manual upload dry-run creation available during read-only maintenance" do
      ENV["READ_ONLY_MAINTENANCE"] = "true"
      content = "# Maintenance dry-run smoke\n"
      uploaded_hash = Digest::SHA256.hexdigest(content)
      staged_upload = Struct.new(:manifest, :artifact_root, :manifest_path).new(
        {
          "source_commit_hash" => "commit-from-maintenance-dry-run",
          "documents" => [],
          "zip_import_preview" => { "warnings" => [] }
        },
        Rails.root.join("tmp", "file-upload-maintenance-smoke"),
        Rails.root.join("tmp", "file-upload-maintenance-smoke", "manifest.json")
      )

      allow(ZipImportStager).to receive(:new).and_return(instance_double(ZipImportStager, call: staged_upload))

      expect {
        post_file_upload(
          content:,
          params: {
            project_code: project.code,
            relative_path: "docs/maintenance-dry-run-smoke.md",
            content_hash: "sha256:#{uploaded_hash}",
            source_commit_hash: "commit-from-maintenance-dry-run"
          }
        )
      }.to change(ImportDryRun, :count).by(1)

      expect(response).to have_http_status(:created)
      dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
      expect(dry_run).to be_manual_upload
      expect(dry_run).to be_analyzed
      expect(response.parsed_body.fetch("file_upload_preview")).to include(
        "relative_path" => "docs/maintenance-dry-run-smoke.md",
        "content_hash" => uploaded_hash
      )
    end

    it "keeps manual file dry-run apply behavior when read-only maintenance is disabled" do
      ENV["READ_ONLY_MAINTENANCE"] = "false"
      dry_run = create_import_dry_run(import_mode: :manual_upload)
      publish_job = create_publish_job
      importer = instance_double(DocumentImporter, call: publish_job)

      expect(DocumentImporter).to receive(:new).and_return(importer)

      post "/api/internal/file_uploads",
        params: { import_dry_run_id: dry_run.public_id },
        headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "publish_job_id" => publish_job.id,
        "status" => "imported",
        "import_dry_run_id" => dry_run.public_id
      )
      expect(dry_run.reload).to be_confirmed
      expect(dry_run.confirmed_by).to eq(actor)
      expect(dry_run.confirmed_at).to be_present
    end
  end

  def auth_headers
    { "Authorization" => "Bearer #{token}" }
  end

  def artifact_apply_params
    {
      artifact_root: Rails.root.join("storage", "imports", "artifact-smoke").to_s,
      manifest_path: Rails.root.join("storage", "imports", "artifact-smoke", "publish.json").to_s
    }
  end

  def create_import_dry_run(import_mode:)
    ImportDryRun.create!(
      import_mode:,
      project:,
      created_by: actor,
      source_commit_hash: "commit-1",
      summary_json: { "total" => 0 },
      result_json: {
        "artifact_root" => Rails.root.join("storage", "imports", "#{import_mode}-smoke").to_s,
        "manifest_path" => Rails.root.join("storage", "imports", "#{import_mode}-smoke", "publish.json").to_s
      },
      warnings_json: [],
      errors_json: []
    )
  end

  def create_publish_job
    PublishJob.create!(
      status: :imported,
      source_repo: "internal-upload-maintenance-spec",
      source_branch: "main",
      source_commit_hash: "commit-1",
      artifact_path: Rails.root.join("storage", "imports", "apply-smoke").to_s,
      log_message: "import completed"
    )
  end

  def post_file_upload(content:, params:)
    Tempfile.create(["maintenance-file-upload", ".md"]) do |file|
      file.write(content)
      file.flush

      post "/api/internal/file_uploads",
        params: params.merge(file: Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "maintenance-upload.md")),
        headers: auth_headers
    end
  end
end
