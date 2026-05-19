require "rails_helper"
require "fileutils"
require "tempfile"
require "zip"

RSpec.describe "API internal upload routes", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "UPLOADAPI", name: "Upload API Project") }
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
    FileUtils.rm_rf(import_root.join("file_uploads"))
    FileUtils.rm_rf(import_root.join("zip_uploads"))
    FileUtils.rm_rf(document_file_root.join("zip_uploads"))
  end

  it "creates a dry-run through the renamed ZIP upload API" do
    zip_file = build_uploaded_zip("docs/README.md" => "# ZIP Upload\n")

    expect do
      post "/api/internal/zip_uploads", params: {
        project_code: project.code,
        zip_file:,
        validate_only: true,
        version_label: "zip-v1"
      }, headers:
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("analyzed")
  ensure
    zip_file&.tempfile&.close!
  end

  it "creates a dry-run from a single uploaded file" do
    uploaded_file = build_uploaded_file("# File Upload\n")

    expect do
      post "/api/internal/file_uploads", params: {
        project_code: project.code,
        file: uploaded_file,
        relative_path: "docs/README.md",
        validate_only: true,
        version_label: "file-v1"
      }, headers:
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("analyzed")
    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.zip?).to eq(true)
    expect(dry_run.result_json["artifact_root"]).to include("/storage/imports/zip_uploads/")
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "rejects unsafe single-file relative paths" do
    uploaded_file = build_uploaded_file("# Unsafe\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "../README.md",
      validate_only: true
    }, headers:

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("relative_path")
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_zip(entries)
    tempfile = Tempfile.new(["zip-upload-request", ".zip"])
    tempfile.binmode

    Zip::File.open(tempfile.path, create: true) do |zip_file|
      entries.each do |path, content|
        zip_file.get_output_stream(path) { _1.write(content) }
      end
    end

    Rack::Test::UploadedFile.new(tempfile.path, "application/zip", original_filename: "sample.zip")
  end

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-request", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
