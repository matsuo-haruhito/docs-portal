require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "DocumentVersionQuality path history metadata" do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Path Metadata Manual") }
  let(:version) { create(:document_version, document:) }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "path-history-quality"))
  end

  def create_metadata_file(content)
    storage_key = "spec/path-history-quality/#{SecureRandom.hex(8)}/.docs-portal-history.yml"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name: ".docs-portal-history.yml",
      content_type: "text/yaml",
      storage_key:,
      file_size: content.bytesize,
      sort_order: 0
    )
  end

  it "reports the metadata source as info" do
    create_metadata_file(<<~YAML)
      path_history:
        slugs:
          - previous-manual
        site_paths:
          - docs/previous-manual
    YAML

    result = DocumentVersionQualityChecker.new(version).call

    check = result.infos.find { _1.key == :path_history_metadata }
    expect(check.message).to eq("Path history metadata source is set")
    expect(check.detail).to eq(".docs-portal-history.yml")
  end

  it "reports archived and deleted status entry counts" do
    create_metadata_file(<<~YAML)
      path_history:
        archived:
          - slug: old-manual
        deleted:
          - site_path: docs/deleted-manual
    YAML

    result = DocumentVersionQualityChecker.new(version).call

    check = result.infos.find { _1.key == :path_history_metadata_status }
    expect(check.message).to eq("Path history metadata status entries are set")
    expect(check.detail).to eq("archived=1, deleted=1")
  end

  it "reports metadata warnings" do
    create_metadata_file(<<~YAML)
      path_history:
        unsupported:
          - previous-manual
    YAML

    result = DocumentVersionQualityChecker.new(version).call

    warning = result.warnings.find { _1.key == :path_history_metadata }
    expect(warning.message).to eq("path_history.unsupported is not supported")
    expect(warning.detail).to eq("unsupported")
  end
end
