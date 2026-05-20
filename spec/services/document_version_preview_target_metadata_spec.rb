require "rails_helper"

RSpec.describe DocumentVersionPreviewTargetMetadata do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def write_file(storage_key, content)
    path = DocumentFile.verified_storage_path(storage_key)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
  end

  def create_document_file(file_name:, storage_key:, content:, content_type: "text/markdown", sort_order: 0)
    write_file(storage_key, content)
    create(:document_file,
      document_version: version,
      file_name:,
      content_type:,
      storage_key:,
      sort_order:,
      file_size: content.bytesize,
      scan_status: :scan_clean)
  end

  it "uses an explicit preview target metadata file before markdown front matter" do
    create_document_file(
      file_name: "README.md",
      storage_key: "spec/preview-target-version/README.md",
      content: <<~MARKDOWN,
        ---
        preview_targets:
          primary: README.md
        ---
      MARKDOWN
      sort_order: 1)
    metadata_file = create_document_file(
      file_name: ".docs-portal-preview.yml",
      storage_key: "spec/preview-target-version/.docs-portal-preview.yml",
      content: <<~YAML,
        preview_targets:
          attachments:
            - attachments/spec.pdf
      YAML
      content_type: "text/yaml",
      sort_order: 0)
    create_document_file(
      file_name: "attachments/spec.pdf",
      storage_key: "spec/preview-target-version/attachments/spec.pdf",
      content: "pdf",
      content_type: "application/pdf",
      sort_order: 2)

    result = described_class.new(version).call

    expect(result.source_file).to eq(metadata_file)
    expect(result.paths_for(:primary)).to eq([])
    expect(result.paths_for(:attachments)).to eq(["attachments/spec.pdf"])
    expect(result).to be_valid
  end

  it "falls back to markdown front matter when no metadata file exists" do
    markdown = create_document_file(
      file_name: "README.md",
      storage_key: "spec/preview-target-version/fallback/README.md",
      content: <<~MARKDOWN,
        ---
        preview_targets:
          primary: README.md
        ---

        # Readme
      MARKDOWN
      sort_order: 0)

    result = described_class.new(version).call

    expect(result.source_file).to eq(markdown)
    expect(result.paths_for(:primary)).to eq(["README.md"])
    expect(result).to be_valid
  end

  it "falls back to mdx front matter when no metadata file exists" do
    mdx = create_document_file(
      file_name: "README.mdx",
      storage_key: "spec/preview-target-version/fallback-mdx/README.mdx",
      content: <<~MARKDOWN,
        ---
        preview_targets:
          primary: README.mdx
        ---

        # Readme
      MARKDOWN
      sort_order: 0)

    result = described_class.new(version).call

    expect(result.source_file).to eq(mdx)
    expect(result.paths_for(:primary)).to eq(["README.mdx"])
    expect(result).to be_valid
  end

  it "returns an empty result when there is no metadata source file" do
    create_document_file(
      file_name: "attachments/spec.pdf",
      storage_key: "spec/preview-target-version/no-source/attachments/spec.pdf",
      content: "pdf",
      content_type: "application/pdf")

    result = described_class.new(version).call

    expect(result.source_file).to be_nil
    expect(result.metadata).to eq({})
    expect(result.warnings).to eq([])
    expect(result).to be_valid
  end

  it "passes parser warnings through" do
    create_document_file(
      file_name: ".preview-targets.yaml",
      storage_key: "spec/preview-target-version/warnings/.preview-targets.yaml",
      content: <<~YAML,
        preview_targets:
          attachments:
            - missing.pdf
      YAML
      content_type: "text/yaml")

    result = described_class.new(version).call

    expect(result.warnings.map(&:code)).to include(:missing_path)
    expect(result.warnings.first.path).to eq("missing.pdf")
  end
end