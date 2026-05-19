require "rails_helper"

RSpec.describe DocumentPathHistoryResolver do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:old_version) do
    create(
      :document_version,
      document:,
      version_label: "v0.9.0",
      markdown_entry_path: "docs/old-guide",
      site_build_path: "docs/old-guide"
    )
  end
  let(:new_version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/new-guide",
      site_build_path: "docs/new-guide"
    )
  end

  before do
    old_version
    new_version
    document.update!(latest_version: new_version)
  end

  it "treats paths under the canonical version as canonical" do
    result = described_class.new(
      document:,
      requested_site_path: "docs/new-guide/intro",
      canonical_version: new_version
    ).call

    expect(result).to be_canonical
    expect(result.canonical_path).to eq("docs/new-guide")
    expect(result.canonical_version).to eq(new_version)
  end

  it "moves old version entry paths to the current canonical entry path" do
    result = described_class.new(
      document:,
      requested_site_path: "docs/old-guide",
      canonical_version: new_version
    ).call

    expect(result).to be_moved
    expect(result.canonical_path).to eq("docs/new-guide")
    expect(result.matched_version).to eq(old_version)
  end

  it "preserves nested suffixes when moving old paths" do
    result = described_class.new(
      document:,
      requested_site_path: "docs/old-guide/appendix/page",
      canonical_version: new_version
    ).call

    expect(result).to be_moved
    expect(result.canonical_path).to eq("docs/new-guide/appendix/page")
  end

  it "returns missing when no canonical or historical match exists" do
    result = described_class.new(
      document:,
      requested_site_path: "docs/unknown",
      canonical_version: new_version
    ).call

    expect(result).to be_missing
    expect(result.canonical_path).to eq("docs/new-guide")
  end
end
