require "rails_helper"
require "digest"
require "tempfile"

RSpec.describe "API internal file uploads", type: :request do
  let(:token) { "test-import-token" }
  let!(:project) { create(:project) }
  let!(:actor) { create(:user, :internal, email_address: "importer@example.com") }

  around do |example|
    previous_token = ENV["DOC_IMPORT_TOKEN"]
    previous_actor = ENV["DOC_IMPORT_ACTOR_EMAIL"]

    ENV["DOC_IMPORT_TOKEN"] = token
    ENV["DOC_IMPORT_ACTOR_EMAIL"] = actor.email_address

    example.run
  ensure
    ENV["DOC_IMPORT_TOKEN"] = previous_token
    ENV["DOC_IMPORT_ACTOR_EMAIL"] = previous_actor
  end

  describe "POST /api/internal/file_uploads" do
    it "creates a manual upload dry-run with bounded preview evidence" do
      content = "# Client upload smoke\n"
      uploaded_hash = Digest::SHA256.hexdigest(content)
      staged_upload = Struct.new(:manifest, :artifact_root, :manifest_path).new(
        {
          "source_commit_hash" => "commit-from-upload-smoke",
          "documents" => [],
          "zip_import_preview" => { "warnings" => [] }
        },
        Rails.root.join("tmp", "file-upload-smoke"),
        Rails.root.join("tmp", "file-upload-smoke", "manifest.json")
      )

      allow(ZipImportStager).to receive(:new).and_return(instance_double(ZipImportStager, call: staged_upload))

      post_file_upload(
        content:,
        params: {
          project_code: project.code,
          relative_path: "docs/client-upload-smoke.md",
          source_name: "client-file-upload-smoke",
          content_hash: "sha256:#{uploaded_hash}",
          source_commit_hash: "commit-from-upload-smoke",
          version_label: "client-upload-smoke-v1"
        }
      )

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      preview = body.fetch("file_upload_preview")
      dry_run = ImportDryRun.find_by!(public_id: body.fetch("dry_run_id"))

      expect(body.slice("dry_run_id", "status", "file_upload_preview").keys).to contain_exactly("dry_run_id", "status", "file_upload_preview")
      expect(body.fetch("status")).to eq("analyzed")
      expect(preview.slice("relative_path", "content_hash", "source_commit_hash", "version_label")).to eq(
        "relative_path" => "docs/client-upload-smoke.md",
        "content_hash" => uploaded_hash,
        "source_commit_hash" => "commit-from-upload-smoke",
        "version_label" => "client-upload-smoke-v1"
      )
      expect(preview.fetch("source_name")).to eq("client-file-upload-smoke")
      expect(preview.fetch("source_path")).to be_nil
      expect(dry_run).to be_manual_upload
      expect(dry_run.project).to eq(project)
      expect(dry_run.created_by).to eq(actor)
      expect(dry_run.result_json.fetch("file_upload_preview")).to include(
        "relative_path" => "docs/client-upload-smoke.md",
        "content_hash" => uploaded_hash,
        "version_label" => "client-upload-smoke-v1"
      )
    end

    it "rejects content_hash mismatch before creating a dry-run" do
      expect {
        post_file_upload(
          content: "# Hash mismatch\n",
          params: {
            project_code: project.code,
            relative_path: "docs/hash-mismatch.md",
            content_hash: "0" * 64
          }
        )
      }.not_to change(ImportDryRun, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.fetch("error")).to eq("content_hash does not match uploaded file")
    end

    it "rejects unsafe relative_path before creating a dry-run" do
      expect {
        post_file_upload(
          content: "# Unsafe path\n",
          params: {
            project_code: project.code,
            relative_path: "../unsafe.md"
          }
        )
      }.not_to change(ImportDryRun, :count)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.fetch("error")).to eq("relative_path is invalid")
    end
  end

  def post_file_upload(content:, params:)
    Tempfile.create(["client-file-upload", ".md"]) do |file|
      file.write(content)
      file.flush

      post "/api/internal/file_uploads",
        params: params.merge(file: Rack::Test::UploadedFile.new(file.path, "text/markdown", false, original_filename: "client-upload.md")),
        headers: { "Authorization" => "Bearer #{token}" }
    end
  end
end
