require "rails_helper"

RSpec.describe ImportDryRunValidator do
  let(:project) { create(:project) }

  it "returns a create item for a new source path" do
    result = described_class.new(
      project:,
      entries: [
        {
          source_path: "docs/manual.md",
          title: "Manual",
          frontmatter: { "category" => "manual" }
        }
      ]
    ).call

    expect(result).to be_valid
    expect(result.creates.size).to eq(1)
    expect(result.creates.first.attributes).to include(
      title: "Manual",
      source_relative_path: "docs/manual.md",
      category: "manual",
      document_kind: "markdown"
    )
  end

  it "returns an update item when the source path already exists" do
    document = create(:document, project:, title: "Manual", slug: "manual")
    version = create(:document_version, document:, source_relative_path: "docs/manual.md")
    document.update!(latest_version: version)

    result = described_class.new(
      project:,
      entries: [{ source_path: "docs/manual.md", title: "Manual" }]
    ).call

    expect(result.updates.size).to eq(1)
    expect(result.updates.first.existing_document).to eq(document)
    expect(result.updates.first.warnings).to include("existing document will receive a new version")
  end

  it "infers title from file name when the title is missing" do
    result = described_class.new(
      project:,
      entries: [{ source_path: "docs/overview.pdf" }]
    ).call

    item = result.items.first
    expect(item.attributes[:title]).to eq("overview")
    expect(item.warnings).to include("title is inferred from file name")
  end

  it "reports invalid source paths without raising" do
    result = described_class.new(
      project:,
      entries: [{ source_path: "../secret.md", title: "Secret" }]
    ).call

    item = result.items.first
    expect(result).not_to be_valid
    expect(item.errors).to include("source path must be a safe relative path")
  end

  it "uses classifier matched rules" do
    result = described_class.new(
      project:,
      entries: [{ source_path: "99_提出済/specification.pdf", title: "Specification" }]
    ).call

    item = result.items.first
    expect(item.matched_rules).to include("submitted_materials")
    expect(item.attributes[:snapshot_kind]).to eq("submitted")
  end
end
