require "digest"
require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file upload content hash", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEHASHALIAS", name: "File Hash Alias Project") }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:document_file_root) { Rails.root.join("storage", "document_files") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return("importer@example.com")

    create(:user, :internal, email_address: "importer@example.com")
  end

  after do
    FileUtils.rm_rf(import_root.join("zip_uploads"))
    FileUtils.rm_rf(document_file_root.join("zip_uploads"))
  end

  it "uses content_hash when source_commit_hash is omitted" do
    file_content = "# Content Hash\n"
    uploaded_file = build_uploaded_file(file_content)
    content_hash = Digest::SHA256.hexdigest(file_content)

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      content_hash: content_hash,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("file_upload_preview", "content_hash")).to eq(content_hash)
    expect(response.parsed_body.dig("file_upload_preview", "source_commit_hash")).to eq(content_hash)

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.source_commit_hash).to eq(content_hash)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "accepts a sha256-prefixed content_hash" do
    file_content = "# Prefixed Content Hash\n"
    uploaded_file = build_uploaded_file(file_content)
    content_hash = Digest::SHA256.hexdigest(file_content)

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      content_hash: "sha256:#{content_hash}",
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("file_upload_preview", "content_hash")).to eq(content_hash)
    expect(response.parsed_body.dig("file_upload_preview", "source_commit_hash")).to eq(content_hash)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "rejects a mismatched content_hash" do
    uploaded_file = build_uploaded_file("# Mismatched Content Hash\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      content_hash: "0" * 64,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("content_hash")
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "prefers source_commit_hash over matching content_hash" do
    file_content = "# Source Hash Wins\n"
    uploaded_file = build_uploaded_file(file_content)
    content_hash = Digest::SHA256.hexdigest(file_content)

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      source_commit_hash: "source-hash-123",
      content_hash: content_hash,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("file_upload_preview", "content_hash")).to eq(content_hash)
    expect(response.parsed_body.dig("file_upload_preview", "source_commit_hash")).to eq("source-hash-123")

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.source_commit_hash).to eq("source-hash-123")
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "rejects a mismatched content_hash even when source_commit_hash is present" do
    uploaded_file = build_uploaded_file("# Source Hash With Bad Content Hash\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      source_commit_hash: "source-hash-123",
      content_hash: "0" * 64,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("content_hash")
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-content-hash", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
