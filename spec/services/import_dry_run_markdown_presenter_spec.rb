require "rails_helper"

RSpec.describe ImportDryRunMarkdownPresenter do
  let(:project) { create(:project) }

  it "renders a markdown preview for import dry-run results" do
    result = ImportDryRunValidator.new(
      project:,
      entries: [
        { source_path: "docs/manual.md", title: "Manual", frontmatter: { "category" => "manual" } },
        { source_path: "../secret.md", title: "Secret" }
      ]
    ).call

    markdown = described_class.new(result).call

    expect(markdown).to include("# Import dry-run preview")
    expect(markdown).to include("## Summary")
    expect(markdown).to include("- total: 2")
    expect(markdown).to include("- creates: 2")
    expect(markdown).to include("- errors: 2")
    expect(markdown).to include("### Manual")
    expect(markdown).to include("- action: create")
    expect(markdown).to include("- source_path: docs/manual.md")
    expect(markdown).to include("- category: manual")
    expect(markdown).to include("### Secret")
    expect(markdown).to include("source path must be a safe relative path")
  end

  it "renders an empty state" do
    result = ImportDryRunValidator::Result.new(items: [])

    markdown = described_class.new(result).call

    expect(markdown).to include("- total: 0")
    expect(markdown).to include("No import candidates.")
  end
end
