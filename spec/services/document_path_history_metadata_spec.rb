require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe DocumentPathHistoryMetadata do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "path-history-metadata"))
  end

  def create_file(file_name:, content:, sort_order: 0)
    storage_key = "spec/path-history-metadata/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type: "text/yaml",
      storage_key:,
      file_size: content.bytesize,
      sort_order:
    )
  end

  it "parses explicit path history metadata" do
    source_file = create_file(
      file_name: ".docs-portal-history.yml",
      content: <<~YAML
        path_history:
          slugs:
            - previous-guide
          site_paths:
            - docs/previous-guide
      YAML
    )

    result = described_class.new(version).call

    expect(result).to be_valid
    expect(result.source_file).to eq(source_file)
    expect(result.slugs).to eq(["previous-guide"])
    expect(result.site_paths).to eq(["docs/previous-guide"])
  end

  it "warns about unknown keys" do
    create_file(
      file_name: "path-history.yaml",
      content: <<~YAML
        path_history:
          slugs:
            - previous-guide
          redirects:
            - old
      YAML
    )

    result = described_class.new(version).call

    warning = result.warnings.find { _1.code == :unknown_key }
    expect(warning.message).to eq("path_history.redirects is not supported")
    expect(warning.detail).to eq("redirects")
  end

  it "returns an empty valid result when no metadata source exists" do
    result = described_class.new(version).call

    expect(result).to be_valid
    expect(result.source_file).to be_nil
    expect(result.slugs).to eq([])
    expect(result.site_paths).to eq([])
  end
end
