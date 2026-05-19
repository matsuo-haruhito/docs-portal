require "rails_helper"

RSpec.describe DocumentPathHistorySummary do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }

  it "lists historical html entry paths for the same document" do
    old_version = create(
      :document_version,
      document:,
      version_label: "v0.9.0",
      markdown_entry_path: "docs/old-guide",
      site_build_path: "docs/old-guide"
    )
    current_version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )

    result = described_class.new(current_version).call

    expect(result).to be_present
    expect(result.canonical_path).to eq("docs/current-guide")
    expect(result.entries.map(&:version)).to contain_exactly(old_version)
    expect(result.paths).to contain_exactly("docs/old-guide")
  end

  it "ignores versions that have the same canonical path" do
    create(
      :document_version,
      document:,
      version_label: "v0.9.0",
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )
    current_version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )

    result = described_class.new(current_version).call

    expect(result).not_to be_present
    expect(result.paths).to eq([])
  end
end
