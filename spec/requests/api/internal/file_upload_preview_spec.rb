require "digest"
require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file upload preview", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEPREVIEW", name: "File Preview Project") }
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

  it "returns and stores source file metadata" do
    file_content = "# File Upload Preview\n"
    uploaded_file = build_uploaded_file(file_content)
    expected_hash = Digest::SHA256.hexdigest(file_content)

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      source_path: "C:/work/docs/README.md",
      source_name: "local-sync",
      version_label: "manual-v1",
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:created)
    preview = response.parsed_body.fetch("file_upload_preview")
    expect(preview["content_hash"]).to eq(expected_hash)
    expect(preview["source_commit_hash"]).to eq(expected_hash)
    expect(preview["file_size"]).to eq(file_content.bytesize)
    expect(preview["source_name"]).to eq("local-sync")
    expect(preview["version_label"]).to eq("manual-v1")

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.source_commit_hash).to eq(expected_hash)
    expect(dry_run.result_json.dig("file_upload_preview", "content_hash")).to eq(expected_hash)
    expect(dry_run.result_json.dig("file_upload_preview", "source_commit_hash")).to eq(expected_hash)
    expect(dry_run.result_json.dig("file_upload_preview", "file_size")).to eq(file_content.bytesize)
    expect(dry_run.result_json.dig("file_upload_preview", "source_name")).to eq("local-sync")
    expect(dry_run.result_json.dig("file_upload_preview", "version_label")).to eq("manual-v1")
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-preview", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
