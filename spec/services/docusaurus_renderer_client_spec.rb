require "rails_helper"
require "tempfile"

RSpec.describe DocusaurusRendererClient do
  let(:endpoint) { "http://renderer.example" }
  let(:client) { described_class.new(endpoint: endpoint) }
  let(:archive) do
    Tempfile.new(["source", ".tar.gz"]).tap do |file|
      file.binmode
      file.write("source archive")
      file.rewind
    end
  end

  after do
    archive.close!
  end

  it "returns a tempfile and site path for successful renderer responses" do
    stub_request(:post, "http://renderer.example/build")
      .with(headers: { "Content-Type" => "application/gzip", "X-Docs-Entry-Path" => "docs/guide.md" })
      .to_return(status: 200, body: "build archive", headers: { "X-Docs-Site-Path" => "docs/guide" })

    result = client.build(archive_file: archive, entry_path: "docs/guide.md")

    expect(result.site_path).to eq("docs/guide")
    expect(result.archive_file.read).to eq("build archive")
  ensure
    result&.archive_file&.close!
  end

  it "normalizes a missing site path header from the entry path" do
    stub_request(:post, "http://renderer.example/build")
      .to_return(status: 200, body: "build archive")

    result = client.build(archive_file: archive, entry_path: "docs/guide.md")

    expect(result.site_path).to eq("docs/guide.md")
  ensure
    result&.archive_file&.close!
  end

  it "raises a readable error when the renderer returns json failure" do
    stub_request(:post, "http://renderer.example/build")
      .to_return(status: 422, body: { error: "MDX parse failed" }.to_json, headers: { "Content-Type" => "application/json" })

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /MDX parse failed/)
  end

  it "rejects invalid site path headers" do
    stub_request(:post, "http://renderer.example/build")
      .to_return(status: 200, body: "build archive", headers: { "X-Docs-Site-Path" => "../escape" })

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /invalid site path/)
  end
end
