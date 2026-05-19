require "rails_helper"
require "fileutils"
require "tempfile"
require "zip"

RSpec.describe "API internal upload dry-run modes", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "DRYMODE", name: "Dry Run Mode Project") }
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

  it "creates a file upload dry-run automatically when file is present" do
    uploaded_file = build_uploaded_file("# Auto Dry Run\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md"
    }, headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch("dry_run_id")).to be_present
    expect(response.parsed_body.fetch("file_upload_preview").fetch("relative_path")).to eq("docs/README.md")

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    expect(dry_run.manual_upload?).to eq(true)
    expect(dry_run.analyzed?).to eq(true)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "does not execute a file upload dry-run through the ZIP endpoint" do
    uploaded_file = build_uploaded_file("# File Dry Run\n")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      relative_path: "docs/README.md",
      validate_only: true
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")

    post "/api/internal/zip_uploads", params: {
      import_dry_run_id: dry_run_id
    }, headers: headers

    expect(response).to have_http_status(:not_found)
    expect(ImportDryRun.find_by!(public_id: dry_run_id).analyzed?).to eq(true)
  ensure
    uploaded_file&.tempfile&.close!
  end

  it "does not execute a ZIP upload dry-run through the file endpoint" do
    zip_file = build_uploaded_zip("docs/README.md" => "# ZIP Dry Run\n")

    post "/api/internal/zip_uploads", params: {
      project_code: project.code,
      zip_file: zip_file,
      validate_only: true
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")

    post "/api/internal/file_uploads", params: {
      import_dry_run_id: dry_run_id
    }, headers: headers

    expect(response).to have_http_status(:not_found)
    expect(ImportDryRun.find_by!(public_id: dry_run_id).analyzed?).to eq(true)
  ensure
    zip_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["upload-dry-run-mode", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end

  def build_uploaded_zip(entries)
    tempfile = Tempfile.new(["upload-dry-run-mode", ".zip"])
    tempfile.binmode

    Zip::File.open(tempfile.path, create: true) do |zip_file|
      entries.each do |path, content|
        zip_file.get_output_stream(path) { |stream| stream.write(content) }
      end
    end

    Rack::Test::UploadedFile.new(tempfile.path, "application/zip", original_filename: "sample.zip")
  end
end
