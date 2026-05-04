require "rails_helper"

RSpec.describe DocumentVersionQualityCheckMarkdown do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }
  let(:version) { create(:document_version, document:, version_label: "v1", status: :published, site_build_path: "missing-site", search_body_text: "internal_only") }

  it "renders quality check result as markdown" do
    result = DocumentVersionQualityChecker.new(version).call

    markdown = described_class.new(result).call

    expect(markdown).to include("# Quality check: Manual")
    expect(markdown).to include("- document: #{document.public_id}")
    expect(markdown).to include("- version: v1")
    expect(markdown).to include("- status: published")
    expect(markdown).to include("- result: fail")
    expect(markdown).to include("## Summary")
    expect(markdown).to include("- errors: #{result.errors.size}")
    expect(markdown).to include("- warnings: #{result.warnings.size}")
    expect(markdown).to include("- infos: #{result.infos.size}")
    expect(markdown).to include("**Error** `rendered_site`")
    expect(markdown).to include("**Warning** `document_files`")
    expect(markdown).to include("**Info** `title`")
  end

  it "renders a passing result" do
    result = DocumentVersionQualityChecker::Result.new(document_version: version, checks: [])

    markdown = described_class.new(result).call

    expect(markdown).to include("- result: pass")
    expect(markdown).to include("- errors: 0")
    expect(markdown).to include("No checks.")
  end
end
