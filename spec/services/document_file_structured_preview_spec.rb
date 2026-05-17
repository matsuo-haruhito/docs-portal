require "rails_helper"

RSpec.describe DocumentFileStructuredPreview do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def write_storage_file(storage_key, content)
    path = DocumentFile.verified_storage_path(storage_key)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
  end

  it "formats valid json" do
    storage_key = "spec/structured-preview/config.json"
    write_storage_file(storage_key, '{"name":"docs","enabled":true}')
    file = create(:document_file, document_version: version, file_name: "config.json", content_type: "application/json", storage_key:)

    preview = described_class.new(file:, viewer_kind: :json).call

    expect(preview).not_to be_error
    expect(preview).not_to be_truncated
    expect(preview.formatted_text).to include("\"name\": \"docs\"")
    expect(preview.formatted_text).to include("\"enabled\": true")
  end

  it "returns an error for invalid json" do
    storage_key = "spec/structured-preview/broken.json"
    write_storage_file(storage_key, '{"name":')
    file = create(:document_file, document_version: version, file_name: "broken.json", content_type: "application/json", storage_key:)

    preview = described_class.new(file:, viewer_kind: :json).call

    expect(preview).to be_error
    expect(preview.formatted_text).to be_nil
  end

  it "formats valid yaml" do
    storage_key = "spec/structured-preview/config.yaml"
    write_storage_file(storage_key, "name: docs\nenabled: true\n")
    file = create(:document_file, document_version: version, file_name: "config.yaml", content_type: "text/yaml", storage_key:)

    preview = described_class.new(file:, viewer_kind: :yaml).call

    expect(preview).not_to be_error
    expect(preview).not_to be_truncated
    expect(preview.formatted_text).to include("name: docs")
    expect(preview.formatted_text).to include("enabled: true")
  end

  it "returns an error for unsafe yaml aliases" do
    storage_key = "spec/structured-preview/unsafe.yaml"
    write_storage_file(storage_key, "default: &default\n  name: docs\ncopy:\n  <<: *default\n")
    file = create(:document_file, document_version: version, file_name: "unsafe.yaml", content_type: "text/yaml", storage_key:)

    preview = described_class.new(file:, viewer_kind: :yaml).call

    expect(preview).to be_error
    expect(preview.formatted_text).to be_nil
  end

  it "falls back to source text for unknown structured viewer kind" do
    storage_key = "spec/structured-preview/plain.txt"
    write_storage_file(storage_key, "raw text\n")
    file = create(:document_file, document_version: version, file_name: "plain.txt", content_type: "text/plain", storage_key:)

    preview = described_class.new(file:, viewer_kind: :unknown).call

    expect(preview).not_to be_error
    expect(preview).not_to be_truncated
    expect(preview.formatted_text).to eq("raw text\n")
  end
end
