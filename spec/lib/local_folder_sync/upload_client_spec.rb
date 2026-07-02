require "rails_helper"
require "fileutils"
require "tempfile"

require Rails.root.join("lib/local_folder_sync/upload_client")

RSpec.describe LocalFolderSync::UploadClient do
  let(:sync_root) { Dir.mktmpdir("local-folder-sync-root") }
  let(:file_path) { File.join(sync_root, "docs", "guide.md") }
  let(:token) { "secret-token-for-client" }
  let(:config) do
    described_class::Config.new(
      portal_url: "https://portal.example.test",
      token: token,
      project_code: "PORTAL",
      sync_root: sync_root,
      source_name: "customer-nas-sync",
      file_path: file_path,
      endpoint: described_class::DEFAULT_ENDPOINT
    )
  end

  after do
    FileUtils.rm_rf(sync_root)
  end

  before do
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "# Guide\n")
  end

  it "builds a dry-run upload request from a file inside the sync root" do
    request = described_class.new(config: config).build_upload_request

    expect(request.relative_path).to eq("docs/guide.md")
    expect(request.project_code).to eq("PORTAL")
    expect(request.source_name).to eq("customer-nas-sync")
    expect(request.content_hash).to eq(Digest::SHA256.hexdigest("# Guide\n"))
  end

  it "rejects upload targets outside the sync root before posting" do
    outside_file = Tempfile.new(["outside", ".md"])
    outside_file.write("# Outside\n")
    outside_file.close

    unsafe_config = described_class::Config.new(
      portal_url: config.portal_url,
      token: config.token,
      project_code: config.project_code,
      sync_root: config.sync_root,
      source_name: config.source_name,
      file_path: outside_file.path,
      endpoint: config.endpoint
    )

    expect { described_class.new(config: unsafe_config).build_upload_request }
      .to raise_error(described_class::Error, "upload target must be inside sync root")
  ensure
    outside_file&.unlink
  end

  it "keeps token and client source_path out of the printable summary" do
    client = described_class.new(config: config)
    payload = {
      "dry_run_id" => "dry_123",
      "status" => "analyzed",
      "sent_relative_path" => "docs/guide.md",
      "sent_content_hash" => "a" * 64,
      "file_upload_preview" => {
        "content_hash" => "a" * 64,
        "source_path" => file_path,
        "source_name" => "customer-nas-sync"
      }
    }

    summary = client.summary_for(payload)

    expect(summary.to_json).not_to include(token)
    expect(summary.to_json).not_to include(file_path)
    expect(summary).to include(
      dry_run_id: "dry_123",
      status: "analyzed",
      relative_path: "docs/guide.md",
      server_hash_matches: true
    )
  end
end
