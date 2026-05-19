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
    FileUtils.rm_rf(import_root.join("zip_uploads"))
    FileUtils.rm_rf(document_file_root.join("zip_uploads"))
  end

  it "creates a dry-run through the renamed ZIP upload API" do
    zip_file = build_uploaded_zip("docs/README.md" => "# ZIP Upload\n")

    expect do
      post "/api/internal/zip_uploads", params: {
        project_code: project.code,
        zip_file: zip_file,
        validate_only: true,
        version_label: "zip-v1"
      }, headers: headers
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
        source_path: "C:/work/docs/README.md",
        validate_only: true,
        version_label: "file-v1"
      }, headers: headers
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("analyzed")
    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.manual_upload?).to eq(true)
    expect(dry_run.result_json["artifact_root"]).to include("/storage/imports/zip_uploads/")
    expect(dry_run.result_json.dig("file_upload_preview", "relative_path")).to eq("docs/README.md")
    expect(dry_run.result_json.dig("file_upload_preview", "source_path")).to eq("C:/work/docs/README.md")
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "imports from a saved single-file dry-run" do
    uploaded_file = build_uploaded_file("# File Upload Import\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      validate_only: true,
      version_label: "file-v1"
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")

    expect do
      post "/api/internal/file_uploads", params: {
        import_dry_run_id: dry_run_id
      }, headers: headers
    end.to change(Document, :count).by(1)
      .and change(DocumentVersion, :count).by(1)
      .and change(DocumentFile, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
    expect(response.parsed_body["import_dry_run_id"]).to eq(dry_run_id)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "rejects unsafe single-file relative paths" do
    [
      "../README.md",
      "/README.md",
      "C:/work/docs/README.md",
      "docs/../README.md"
    ].each do |relative_path|
      expect_file_upload_path_to_be_rejected(relative_path)
    end
  end

  private

  def expect_file_upload_path_to_be_rejected(relative_path)
    uploaded_file = build_uploaded_file("# Unsafe\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: relative_path,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("relative_path")
  ensure
    uploaded_file&.tempfile&.close!
  end

  def build_uploaded_zip(entries)
    tempfile = Tempfile.new(["zip-upload-request", ".zip"])
    tempfile.binmode

    Zip::File.open(tempfile.path, create: true) do |zip_file|
      entries.each do |path, content|
        zip_file.get_output_stream(path) { |stream| stream.write(content) }
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
