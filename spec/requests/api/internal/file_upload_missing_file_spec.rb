require "rails_helper"

RSpec.describe "API internal file upload missing file", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:project) { create(:project, code: "FILEMISS", name: "File Missing Project") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return("importer@example.com")

    create(:user, :internal, email_address: "importer@example.com")
  end

  it "rejects explicit dry-run requests without a file" do
    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      relative_path: "docs/README.md",
      validate_only: true
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("file")
  end

  it "treats requests without file and without dry-run id as execution requests" do
    post "/api/internal/file_uploads", params: {
      project_code: project.code,
      relative_path: "docs/README.md"
    }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("import_dry_run_id")
  end
end
