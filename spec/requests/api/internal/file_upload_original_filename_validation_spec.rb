require "rails_helper"
require "tempfile"

RSpec.describe "API internal file upload original filename validation", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEORIGVALID", name: "File Original Name Validation Project") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return("importer@example.com")

    create(:user, :internal, email_address: "importer@example.com")
  end

  it "rejects an unsafe original filename when relative_path is omitted" do
    uploaded_file = build_uploaded_file("# Unsafe Original Name\n", original_filename: "../README.md")

    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      file: uploaded_file,
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("relative_path")
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_file(content, original_filename:)
    tempfile = Tempfile.new(["file-upload-original-filename-validation", ".md"])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: original_filename)
  end
end
