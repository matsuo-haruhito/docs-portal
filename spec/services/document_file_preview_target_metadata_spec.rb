require "rails_helper"

RSpec.describe DocumentFilePreviewTargetMetadata do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }
  let(:document_files) do
    [
      build(:document_file, document_version: version, file_name: "README.md"),
      build(:document_file, document_version: version, file_name: "attachments/spec.pdf"),
      build(:document_file, document_version: version, file_name: "debug/raw.json")
    ]
  end

  def parse(source)
    described_class.new(source:, document_files:).call
  end

  it "parses preview target metadata from front matter" do
    source = <<~MARKDOWN
      ---
      title: Guide
      preview_targets:
        primary: README.md
        attachments:
          - attachments/spec.pdf
        debug:
          raw: debug/raw.json
      ---

      # Guide
    MARKDOWN

    result = parse(source)

    expect(result).to be_valid
    expect(result.paths_for(:primary)).to eq(["README.md"])
    expect(result.paths_for(:attachments)).to eq(["attachments/spec.pdf"])
    expect(result.paths_for(:debug)).to eq(["debug/raw.json"])
  end

  it "parses preview target metadata from a plain yaml source" do
    result = parse(<<~YAML)
      preview_targets:
        hidden:
          - debug/raw.json
    YAML

    expect(result).to be_valid
    expect(result.paths_for(:hidden)).to eq(["debug/raw.json"])
  end

  it "warns about unknown keys" do
    result = parse(<<~YAML)
      preview_targets:
        primary: README.md
        unknown: README.md
    YAML

    expect(result.warnings.map(&:code)).to include(:unknown_key)
    expect(result.warnings.map(&:message)).to include("preview_targets.unknown は未対応です")
  end

  it "warns about missing paths" do
    result = parse(<<~YAML)
      preview_targets:
        attachments:
          - missing.pdf
    YAML

    warning = result.warnings.find { _1.code == :missing_path }
    expect(warning.path).to eq("missing.pdf")
    expect(warning.message).to include("attachments")
  end

  it "warns about duplicated paths across target groups" do
    result = parse(<<~YAML)
      preview_targets:
        primary: README.md
        attachments:
          - README.md
    YAML

    warning = result.warnings.find { _1.code == :duplicate_path }
    expect(warning.path).to eq("README.md")
  end

  it "warns about unsafe relative paths and reports the remaining valid paths" do
    result = parse(<<~YAML)
      preview_targets:
        attachments:
          - ../outside.txt
          - /attachments/spec.pdf
    YAML

    expect(result.paths_for(:attachments)).to eq(["attachments/spec.pdf"])
    warning = result.warnings.find { _1.code == :unsafe_relative_path }
    expect(warning.path).to eq("../outside.txt")
    expect(warning.message).to include("安全ではない相対パス")
  end

  it "returns an invalid yaml warning" do
    result = parse(<<~YAML)
      preview_targets:
        primary: [
    YAML

    expect(result.metadata).to eq({})
    expect(result.warnings.map(&:code)).to include(:invalid_yaml)
  end
end
