require "rails_helper"
require "fileutils"

RSpec.describe "API internal artifact imports", type: :request do
  let(:token) { "secret-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:artifact_root) { import_root.join("artifact-upload-route") }
  let(:manifest_path) { artifact_root.join("manifest.json") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DOC_IMPORT_ACTOR_EMAIL").and_return("importer@example.com")

    FileUtils.mkdir_p(artifact_root.join("attachments"))
    create(:user, :internal, email_address: "importer@example.com")
  end

  after do
    FileUtils.rm_rf(import_root)
  end

  it "accepts a manifest artifact through the renamed artifact import API" do
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc",
        documents: []
      }.to_json
    )

    post "/api/internal/artifact_imports", params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers:

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
  end

  it "creates a dry-run through the renamed artifact import API" do
    project = create(:project, code: "ARTIFACT", name: "Artifact Project")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc123",
        documents: [
          {
            project_code: project.code,
            slug: "new-doc",
            title: "New Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            source_relative_path: "docs/new-doc.md"
          }
        ]
      }.to_json
    )

    expect do
      post "/api/internal/artifact_imports", params: {
        artifact_root: artifact_root.to_s,
        manifest_path: manifest_path.to_s,
        validate_only: true
      }, headers:
    end.to change(ImportDryRun, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("analyzed")
    expect(response.parsed_body["summary"]["create_count"]).to eq(1)
  end
end
