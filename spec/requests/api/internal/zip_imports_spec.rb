require "rails_helper"
require "fileutils"
require "tempfile"
require "zip"

RSpec.describe "API internal zip imports", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "ZIPIMPORT", name: "ZIP Import Project") }
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

  it "returns and saves a zip dry-run in validate_only mode" do
    zip_file = build_uploaded_zip(
      "docs/README.md" => "# Overview\n\n![Guide](assets/guide.png)\n",
      "docs/assets/guide.png" => "image",
      "docs/notes.txt" => "orphan"
    )

    expect do
      post api_internal_zip_imports_path, params: {
        project_code: project.code,
        zip_file:,
        validate_only: true,
        version_label: "zip-v1"
      }, headers: headers
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["valid"]).to eq(true)
    expect(response.parsed_body["status"]).to eq("analyzed")
    expect(response.parsed_body["dry_run_id"]).to be_present
    expect(response.parsed_body.dig("zip_import_preview", "orphan_files")).to contain_exactly("docs/notes.txt")

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body["dry_run_id"])
    expect(dry_run.zip?).to eq(true)
    expect(dry_run.project).to eq(project)
    expect(dry_run.result_json["artifact_root"]).to include("/storage/imports/zip_uploads/")
    expect(dry_run.result_json["manifest_path"]).to end_with("/manifest.json")
    expect(dry_run.result_json.dig("zip_import_preview", "orphan_files")).to contain_exactly("docs/notes.txt")
  ensure
    zip_file&.tempfile&.close!
  end

  it "imports from a saved zip dry-run" do
    zip_file = build_uploaded_zip(
      "docs/README.md" => "# Imported\n\n![Guide](assets/guide.png)\n",
      "docs/assets/guide.png" => "image"
    )

    post api_internal_zip_imports_path, params: {
      project_code: project.code,
      zip_file:,
      validate_only: true,
      version_label: "zip-v1"
    }, headers: headers
    dry_run_id = response.parsed_body.fetch("dry_run_id")

    expect do
      post api_internal_zip_imports_path, params: {
        import_dry_run_id: dry_run_id
      }, headers: headers
    end.to change(Document, :count).by(1)
      .and change(DocumentVersion, :count).by(1)
      .and change(DocumentFile, :count).by(2)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
    expect(response.parsed_body["import_dry_run_id"]).to eq(dry_run_id)

    document = project.documents.find_by!(slug: "docs")
    expect(document.title).to eq("Imported")
    expect(document.latest_version).to be_present
    expect(document.latest_version.source_relative_path).to eq("docs/README.md")
    expect(document.latest_version.document_files.map(&:file_name)).to contain_exactly("docs/README.md", "docs/assets/guide.png")

    dry_run = ImportDryRun.find_by!(public_id: dry_run_id)
    expect(dry_run.confirmed?).to eq(true)
  ensure
    zip_file&.tempfile&.close!
  end

  it "rejects execution without a saved dry-run id" do
    post api_internal_zip_imports_path, params: {}, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("import_dry_run_id is required")
  end

  it "rejects zip entries that escape the extraction root" do
    zip_file = build_uploaded_zip("../outside.md" => "# nope\n")

    post api_internal_zip_imports_path, params: {
      project_code: project.code,
      zip_file:,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("ZIP entry path is invalid")
  ensure
    zip_file&.tempfile&.close!
  end

  private

  def build_uploaded_zip(entries)
    tempfile = Tempfile.new(["zip-import-request", ".zip"])
    tempfile.binmode

    Zip::File.open(tempfile.path, create: true) do |zip_file|
      entries.each do |path, content|
        zip_file.get_output_stream(path) { _1.write(content) }
      end
    end

    Rack::Test::UploadedFile.new(tempfile.path, "application/zip", original_filename: "sample.zip")
  end
end
