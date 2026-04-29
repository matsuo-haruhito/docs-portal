require "rails_helper"
require "fileutils"

RSpec.describe "API internal doc imports", type: :request do
  let(:token) { "secret-token" }
  let(:import_root) { Rails.root.join("storage", "imports") }
  let(:artifact_root) { import_root.join("artifact-set") }
  let(:manifest_path) { artifact_root.join("manifest.json") }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOC_IMPORT_TOKEN", "").and_return(token)

    FileUtils.mkdir_p(artifact_root.join("attachments"))
    create(:user, :internal, email_address: "admin@example.com")
  end

  after do
    FileUtils.rm_rf(import_root)
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "imports-spec"))
  end

  it "rejects import paths outside the allowed import root" do
    outside_manifest = Rails.root.join("tmp", "outside-manifest.json")
    FileUtils.mkdir_p(outside_manifest.dirname)
    File.write(outside_manifest, { source_repo: "repo", source_branch: "main", source_commit_hash: "abc", documents: [] }.to_json)

    post api_internal_doc_imports_path, params: {
      artifact_root: outside_manifest.dirname.to_s,
      manifest_path: outside_manifest.to_s
    }, headers:

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to include("allowed import root")
  ensure
    FileUtils.rm_f(outside_manifest)
  end

  it "rejects invalid storage_key values" do
    project = create(:project, code: "PJIMPORT", name: "Import Project")
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc",
        documents: [
          {
            project_code: project.code,
            slug: "imported-doc",
            title: "Imported Doc",
            category: "spec",
            document_kind: "mixed",
            visibility_policy: "restricted_external",
            version_label: "v1.0.0",
            status: "published",
            files: [
              {
                file_name: "bad.txt",
                content_type: "text/plain",
                storage_key: "../bad.txt",
                file_size: 4
              }
            ]
          }
        ]
      }.to_json
    )

    post api_internal_doc_imports_path, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers:

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body["error"]).to include("storage_key")
  end

  it "accepts a valid import path within the allowed root" do
    File.write(
      manifest_path,
      {
        source_repo: "repo",
        source_branch: "main",
        source_commit_hash: "abc",
        documents: []
      }.to_json
    )

    post api_internal_doc_imports_path, params: {
      artifact_root: artifact_root.to_s,
      manifest_path: manifest_path.to_s
    }, headers:

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["status"]).to eq("imported")
  end
end
