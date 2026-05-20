require "rails_helper"
require "tempfile"

RSpec.describe DocusaurusRendererClient do
  let(:endpoint) { "http://renderer.example" }
  let(:client) { described_class.new(endpoint: endpoint) }
  let(:http) { instance_double(Net::HTTP) }
  let(:archive) do
    Tempfile.new(["source", ".tar.gz"]).tap do |file|
      file.binmode
      file.write("source archive")
      file.rewind
    end
  end

  before do
    allow(Net::HTTP).to receive(:new).with("renderer.example", 80).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  after do
    archive.close!
  end

  it "returns a tempfile and site path for successful renderer responses" do
    allow(http).to receive(:request).and_return(success_response("build archive", "docs/guide"))

    result = client.build(archive_file: archive, entry_path: "docs/guide.md")

    expect(result.site_path).to eq("docs/guide")
    expect(result.archive_file.read).to eq("build archive")
    expect(http).to have_received(:request) do |request|
      expect(request["Content-Type"]).to eq("application/gzip")
      expect(request["X-Docs-Entry-Path"]).to eq("docs/guide.md")
      expect(request.content_length).to eq(archive.size)
    end
  ensure
    result&.archive_file&.close!
  end

  it "normalizes a missing site path header from the entry path" do
    allow(http).to receive(:request).and_return(success_response("build archive"))

    result = client.build(archive_file: archive, entry_path: "docs/guide.md")

    expect(result.site_path).to eq("docs/guide")
  ensure
    result&.archive_file&.close!
  end

  it "normalizes a missing site path header from nested index entry paths" do
    allow(http).to receive(:request).and_return(success_response("build archive"))

    result = client.build(archive_file: archive, entry_path: "docs/guide/index.md")

    expect(result.site_path).to eq("docs/guide")
  ensure
    result&.archive_file&.close!
  end

  it "normalizes a missing site path header from README entry paths" do
    allow(http).to receive(:request).and_return(success_response("build archive"))

    result = client.build(archive_file: archive, entry_path: "docs/guide/README.mdx")

    expect(result.site_path).to eq("docs/guide")
  ensure
    result&.archive_file&.close!
  end

  it "accepts site path headers that normalize within the site tree" do
    allow(http).to receive(:request).and_return(success_response("build archive", "docs/../docs/guide"))

    result = client.build(archive_file: archive, entry_path: "docs/guide.md")

    expect(result.site_path).to eq("docs/guide")
  ensure
    result&.archive_file&.close!
  end

  it "raises a readable error when the renderer returns json failure" do
    allow(http).to receive(:request).and_return(error_response({ error: "MDX parse failed" }.to_json))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /MDX parse failed/)
  end

  it "raises a readable error when the renderer returns json message failure" do
    allow(http).to receive(:request).and_return(error_response({ message: "Renderer crashed" }.to_json))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /Renderer crashed/)
  end

  it "raises a readable error when the renderer returns json errors failure" do
    allow(http).to receive(:request).and_return(error_response({ errors: ["MDX failed", "Broken link"] }.to_json))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /MDX failed, Broken link/)
  end

  it "rejects empty successful renderer artifacts" do
    allow(http).to receive(:request).and_return(success_response(""))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /empty artifact/)
  end

  it "raises a transient error when the renderer does not respond" do
    allow(http).to receive(:request).and_raise(Errno::ECONNREFUSED.new("renderer"))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(DocusaurusRendererClient::TransientError, /did not respond/)
  end

  it "rejects invalid site path headers" do
    allow(http).to receive(:request).and_return(success_response("build archive", "../escape"))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /invalid site path/)
  end

  it "rejects Windows absolute site path headers" do
    allow(http).to receive(:request).and_return(success_response("build archive", "C:\\tmp\\guide"))

    expect do
      client.build(archive_file: archive, entry_path: "docs/guide.md")
    end.to raise_error(ApplicationError::BadRequest, /invalid site path/)
  end

  private

  def success_response(body, site_path = nil)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      set_response_body(response, body)
      response["X-Docs-Site-Path"] = site_path if site_path
    end
  end

  def error_response(body)
    Net::HTTPUnprocessableEntity.new("1.1", "422", "Unprocessable Entity").tap do |response|
      set_response_body(response, body)
    end
  end

  def set_response_body(response, body)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
  end
end
