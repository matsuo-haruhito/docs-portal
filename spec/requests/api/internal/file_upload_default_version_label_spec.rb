require "digest"
require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "API internal file upload default version label", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEVER", name: "File Version Project") }
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

  it "uses a timestamp and source hash prefix when version_label is omitted" do
    file_content = "# Default Version Label\n"
    uploaded_file = build_uploaded_file(file_content)
    hash_prefix = Digest::SHA256.hexdigest(file_content).first(8)

    travel_to Time.zone.local(2026, 5, 19, 10, 30, 45) do
      post "/api/internal/file_uploads", params: {
        project_code: project.code,
        file: uploaded_file,
        relative_path: "docs/README.md",
        validate_only: true
      }, headers: headers
    end

    expect(response).to have_http_status(:created)
    expected_label = "file-20260519103045-#{hash_prefix}"
    expect(response.parsed_body.dig("file_upload_preview", "version_label")).to eq(expected_label)

    dry_run = ImportDryRun.find_by!(public_id: response.parsed_body.fetch("dry_run_id"))
    manifest = JSON.parse(File.read(dry_run.result_json.fetch("manifest_path")))
    expect(manifest.dig("documents", 0, "version_label")).to eq(expected_label)
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content)
    tempfile = Tempfile.new(["file-upload-default-version", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "README.md")
  end
end
