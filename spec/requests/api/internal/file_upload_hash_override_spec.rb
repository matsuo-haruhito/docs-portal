require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file upload source hash override", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEHASH", name: "File Hash Project") }
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

  it "uses a client supplied source_commit_hash when present" do
    uploaded_file = build_uploaded_file("# Hash Override\n")
    source_commit_hash = "client-hash-123"

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      source_commit_hash: source_commit_hash
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("file_upload_preview", "source_commit_hash")).to eq(source_commit_hash)

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.source_commit_hash).to eq(source_commit_hash)
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-hash-override", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
