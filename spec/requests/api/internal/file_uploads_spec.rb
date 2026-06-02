require "rails_helper"
require "digest"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file uploads", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEAPI", name: "File Upload API Project") }
  let(:actor) { create(:user, :internal, email_address: "importer@example.com") }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:document_file_root) { Rails.root.join("storage", "document_files") }
  let(:endpoint) { "/api/internal/file_uploads" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return(actor.email_address)
  end

  after do
    FileUtils.rm_rf(import_root.join("zip_uploads"))
    FileUtils.rm_rf(document_file_root.join("zip_uploads"))
  end

  it "returns and saves a manual upload dry-run with preview metadata" do
    content = "# Manual Upload\n\n![Guide](assets/guide.png)\n"
    content_hash = Digest::SHA256.hexdigest(content)
    uploaded_file = build_uploaded_file(content, original_filename: "README.md")

    expect do
      post endpoint, params: {
        project_code: project.code,
        file: uploaded_file,
        relative_path: "docs/README.md",
        source_name: "local-folder-sync",
        source_path: "/workspace/docs/README.md",
        content_hash: "sha256:#{content_hash}",
        version_label: "manual-v1"
      }, headers: headers
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch("dry_run_id")).to be_present
    expect(response.parsed_body.fetch("status")).to eq("analyzed")
    expect(response.parsed_body).to have_key("expires_at")

    preview = response.parsed_body.fetch("file_upload_preview")
    expect(preview).to include(
      "source_name" => "local-folder-sync",
      "relative_path" => "docs/README.md",
      "source_path" => "/workspace/docs/README.md",
      "file_size" => content.bytesize,
      "content_hash" => content_hash,
      "source_commit_hash" => content_hash,
      "version_label" => "manual-v1"
    )
    expect(preview.fetch("zip_import_preview")).to include("orphan_files", "skipped_files", "warnings")

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.manual_upload?).to eq(true)
    expect(dry_run.analyzed?).to eq(true)
    expect(dry_run.project).to eq(project)
    expect(dry_run.created_by).to eq(actor)
    expect(dry_run.source_commit_hash).to eq(content_hash)
    expect(dry_run.result_json["artifact_root"]).to include("/storage/imports/zip_uploads/")
    expect(dry_run.result_json["manifest_path"]).to end_with("/manifest.json")
    expect(dry_run.result_json.fetch("file_upload_preview")).to eq(preview)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "accepts a bare SHA-256 content_hash" do
    content = "# Bare Hash\n"
    content_hash = Digest::SHA256.hexdigest(content)
    uploaded_file = build_uploaded_file(content)

    post endpoint, params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/bare.md",
      content_hash: content_hash
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("file_upload_preview", "content_hash")).to eq(content_hash)
    expect(response.parsed_body.dig("file_upload_preview", "source_commit_hash")).to eq(content_hash)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "rejects malformed and mismatched content_hash values" do
    malformed_file = build_uploaded_file("# Malformed\n")
    post endpoint, params: {
      project_code: project.code,
      file: malformed_file,
      relative_path: "docs/malformed.md",
      content_hash: "sha256:not-a-digest"
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.fetch("error")).to include("content_hash must be a SHA-256 hex digest")

    mismatched_file = build_uploaded_file("# Mismatch\n")
    post endpoint, params: {
      project_code: project.code,
      file: mismatched_file,
      relative_path: "docs/mismatch.md",
      content_hash: "0" * 64
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body.fetch("error")).to include("content_hash does not match uploaded file")
  ensure
    malformed_file&.tempfile&.close!
    mismatched_file&.tempfile&.close!
  end

  it "rejects unsafe relative_path values" do
    ["../outside.md", "/absolute.md", "C:/tmp/outside.md"].each do |relative_path|
      uploaded_file = build_uploaded_file("# Unsafe\n")

      begin
        post endpoint, params: {
          project_code: project.code,
          file: uploaded_file,
          relative_path: relative_path
        }, headers: headers

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body.fetch("error")).to include("relative_path is invalid")
      ensure
        uploaded_file&.tempfile&.close!
      end
    end
  end

  it "rejects ZIP mode dry-runs on the file upload apply endpoint" do
    dry_run = create_dry_run(import_mode: :zip, status: :analyzed)

    post endpoint, params: { import_dry_run_id: dry_run.public_id }, headers: headers

    expect(response).to have_http_status(:not_found)
    expect(dry_run.reload.analyzed?).to eq(true)
  end

  it "rejects non-analyzed manual upload dry-runs on apply" do
    %i[confirmed expired failed].each do |status|
      dry_run = create_dry_run(import_mode: :manual_upload, status: status)

      post endpoint, params: { import_dry_run_id: dry_run.public_id }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(dry_run.reload.public_send("#{status}?")).to eq(true)
    end
  end

  private

  def build_uploaded_file(content, original_filename: "README.md")
    tempfile = Tempfile.new(["file-upload-request", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: original_filename)
  end

  def create_dry_run(import_mode:, status:)
    ImportDryRun.create!(
      import_mode: import_mode,
      status: status,
      project: project,
      created_by: actor,
      source_commit_hash: "abc123",
      summary_json: { "documents" => 0 },
      result_json: { "valid" => true },
      warnings_json: [],
      errors_json: []
    )
  end
end
