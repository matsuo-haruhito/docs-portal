require "rails_helper"

RSpec.describe "DocumentVersionQuality path history" do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Path History Manual") }

  it "warns when the document version has historical preview paths" do
    create(
      :document_version,
      document:,
      version_label: "v0.9.0",
      markdown_entry_path: "docs/previous-manual",
      site_build_path: "docs/previous-manual"
    )
    current_version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/current-manual",
      site_build_path: "docs/current-manual"
    )

    result = DocumentVersionQualityChecker.new(current_version).call

    warning = result.warnings.find { _1.key == :path_history }
    expect(warning.message).to eq("Document has historical preview paths that redirect to the current path")
    expect(warning.detail).to eq("docs/previous-manual -> docs/current-manual")
  end

  it "does not warn when there are no historical preview paths" do
    current_version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/current-manual",
      site_build_path: "docs/current-manual"
    )

    result = DocumentVersionQualityChecker.new(current_version).call

    expect(result.warnings.map(&:key)).not_to include(:path_history)
  end
end
