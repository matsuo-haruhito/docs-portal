require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file upload cleanup", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILECLEAN", name: "File Cleanup Project") }
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

  it "can execute a dry-run after the temporary upload zip has been closed" do
    uploaded_file = build_uploaded_file("# Cleanup\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md"
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")
    dry_run = ImportDryRun.find_by!(public_id: dry_run_id)

    expect(File).to exist(dry_run.result_json.fetch("manifest_path"))
    expect(Dir.exist?(dry_run.result_json.fetch("artifact_root"))).to eq(true)

    post "/api/internal/file_uploads", params: {
      import_dry_run_id: dry_run_id
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-cleanup", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
