require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file upload source metadata", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILESRC", name: "File Source Project") }
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

  it "stores source_path only in file_upload_preview" do
    uploaded_file = build_uploaded_file("# Source Metadata\n")
    source_path = "local-sync/docs/README.md"

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      source_path: source_path,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:created)
    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    manifest_path = Pathname(dry_run.result_json.fetch("manifest_path"))
    manifest = JSON.parse(File.read(manifest_path))

    expect(manifest["source_branch"]).to eq("docs/README.md")
    expect(manifest["source_branch"]).not_to eq(source_path)
    expect(dry_run.result_json.dig("file_upload_preview", "source_path")).to eq(source_path)
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-source-metadata", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
