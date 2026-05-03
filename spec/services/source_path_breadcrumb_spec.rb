require "rails_helper"

RSpec.describe SourcePathBreadcrumb do
  let(:project) { create(:project, code: "BREAD", name: "Breadcrumb Project") }
  let(:document) { create(:document, project:, title: "設計書", slug: "design-doc") }

  it "builds project, directory, and file crumbs from source path metadata" do
    version = create(:document_version, document:)
    version.assign_source_path_metadata!(source_path: "docs/design/overview.md")
    version.save!

    crumbs = described_class.new(document:, version:, project:).crumbs

    expect(crumbs.map(&:label)).to eq(["Breadcrumb Project", "docs", "design", "overview.md"])
    expect(crumbs.map(&:path)).to eq([nil, "docs", "docs/design", "docs/design/overview.md"])
    expect(crumbs.first.url).to eq(Rails.application.routes.url_helpers.project_path(project))
    expect(crumbs.second.url).to eq(Rails.application.routes.url_helpers.project_documents_path(project, q: "docs"))
  end

  it "returns no crumbs when source metadata is absent" do
    version = create(:document_version, document:)

    crumbs = described_class.new(document:, version:, project:).crumbs

    expect(crumbs).to eq([])
  end
end
