require "rails_helper"

RSpec.describe ProjectTemplateApplier do
  let(:project) { create(:project, code: "TPL") }

  it "creates documents and draft versions from the standard template" do
    result = described_class.new(project:, source_commit_hash: "template-sha").call

    expect(result.created_count).to be_positive
    expect(result.skipped_count).to eq(0)
    document = project.documents.find_by!(title: "業務フロー")
    version = document.latest_version
    expect(document.slug).to eq("01-md")
    expect(document.category).to eq("spec")
    expect(document.document_kind).to eq("markdown")
    expect(document.visibility_policy).to eq("internal_only")
    expect(version).to be_draft
    expect(version.version_label).to eq("template")
    expect(version.source_commit_hash).to eq("template-sha")
    expect(version.source_relative_path).to eq("01_要件定義/業務フロー.md")
    expect(version.search_body_text).to include("業務の流れ")
  end

  it "skips existing template documents" do
    existing = create(:document, project:, title: "要件定義 README", slug: "01-readme-md")
    version = create(:document_version, document: existing, source_relative_path: "01_要件定義/README.md")
    existing.update!(latest_version: version)

    result = described_class.new(project:).call

    expect(result.skipped_documents).to include(existing)
    expect(project.documents.where(title: "要件定義 README").count).to eq(1)
  end
end
