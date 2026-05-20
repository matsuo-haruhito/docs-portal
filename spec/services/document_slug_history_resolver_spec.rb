require "rails_helper"

RSpec.describe DocumentSlugHistoryResolver do
  let(:project) { create(:project) }

  it "moves a historical source file slug to the current document" do
    document = create(:document, project:, slug: "current-guide")
    version = create(
      :document_version,
      document:,
      source_file_name: "previous-guide.md",
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )

    result = described_class.new(project:, requested_slug: "previous-guide").call

    expect(result).to be_moved
    expect(result.canonical_document).to eq(document)
    expect(result.matched_version).to eq(version)
    expect(result.matched_source).to eq("previous-guide")
  end

  it "moves a historical html entry segment to the current document" do
    document = create(:document, project:, slug: "current-guide")
    create(
      :document_version,
      document:,
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/previous-guide"
    )

    result = described_class.new(project:, requested_slug: "previous-guide").call

    expect(result).to be_moved
    expect(result.canonical_document).to eq(document)
    expect(result.matched_source).to eq("previous-guide")
  end

  it "returns missing when no historical slug source matches" do
    create(:document, project:, slug: "current-guide")

    result = described_class.new(project:, requested_slug: "unknown-guide").call

    expect(result).to be_missing
  end
end
