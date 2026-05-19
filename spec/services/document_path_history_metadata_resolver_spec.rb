require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document path history metadata resolver integration" do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, slug: "current-guide") }
  let(:version) do
    create(
      :document_version,
      document:,
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "path-history-resolver"))
  end

  def create_metadata_file(content)
    storage_key = "spec/path-history-resolver/#{SecureRandom.hex(8)}/.docs-portal-history.yml"
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

  it "uses explicit site path metadata before inferred historical version paths" do
    create_metadata_file(<<~YAML)
      path_history:
        site_paths:
          - docs/explicit-previous-guide
    YAML

    result = DocumentPathHistoryResolver.new(
      document:,
      requested_site_path: "docs/explicit-previous-guide",
      canonical_version: version
    ).call

    expect(result).to be_moved
    expect(result.canonical_path).to eq("docs/current-guide")
    expect(result.matched_version).to eq(version)
  end

  it "uses explicit slug metadata before inferred source path candidates" do
    create_metadata_file(<<~YAML)
      path_history:
        slugs:
          - explicit-previous-guide
    YAML

    result = DocumentSlugHistoryResolver.new(project:, requested_slug: "explicit-previous-guide").call

    expect(result).to be_moved
    expect(result.canonical_document).to eq(document)
    expect(result.matched_version).to eq(version)
    expect(result.matched_source).to eq("explicit-previous-guide")
  end

  it "resolves archived site paths from metadata" do
    create_metadata_file(<<~YAML)
      path_history:
        archived:
          - site_path: docs/archived-guide
            reason: old publication
    YAML

    result = DocumentPathHistoryResolver.new(
      document:,
      requested_site_path: "docs/archived-guide",
      canonical_version: version
    ).call

    expect(result).to be_archived
    expect(result).to be_terminal
    expect(result.matched_entry.reason).to eq("old publication")
    expect(result.canonical_path).to eq("docs/current-guide")
  end

  it "resolves deleted slugs from metadata" do
    create_metadata_file(<<~YAML)
      path_history:
        deleted:
          - slug: deleted-guide
            reason: removed from scope
    YAML

    result = DocumentSlugHistoryResolver.new(project:, requested_slug: "deleted-guide").call

    expect(result).to be_deleted
    expect(result).to be_terminal
    expect(result.canonical_document).to eq(document)
    expect(result.matched_entry.reason).to eq("removed from scope")
  end
end
