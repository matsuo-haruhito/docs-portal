require "rails_helper"

RSpec.describe ImportDryRunHashPresenter do
  let(:project) { create(:project) }

  it "renders dry-run results as a hash suitable for JSON responses" do
    document = create(:document, project:, title: "Existing", slug: "existing")
    version = create(:document_version, document:, source_relative_path: "docs/existing.md")
    document.update!(latest_version: version)

    result = ImportDryRunValidator.new(
      project:,
      entries: [
        { source_path: "docs/new.md", title: "New" },
        { source_path: "docs/existing.md", title: "Existing" },
        { source_path: "../secret.md", title: "Secret" }
      ]
    ).call

    hash = described_class.new(result).call

    expect(hash[:valid]).to be(false)
    expect(hash[:summary]).to include(
      valid: false,
      total: 3,
      create_count: 2,
      update_count: 1,
      valid_count: 2,
      invalid_count: 1,
      warning_count: 1,
      error_count: 2
    )
    expect(hash[:summary][:source_paths]).to eq(["docs/new.md", "docs/existing.md", "../secret.md"])

    update_item = hash[:items].find { _1[:action] == :update }
    expect(update_item).to include(
      valid: true,
      source_path: "docs/existing.md",
      title: "Existing",
      existing_document_id: document.public_id
    )

    invalid_item = hash[:items].find { _1[:source_path] == "../secret.md" }
    expect(invalid_item[:valid]).to be(false)
    expect(invalid_item[:errors]).to include("source path must be a safe relative path")
  end

  it "includes duplicate candidate details in the JSON-friendly hash" do
    duplicate = create(:document, project:, title: "Operation Manual", slug: "operation-manual")
    version = create(:document_version, document: duplicate, source_relative_path: "docs/reference.pdf", source_basename: "reference")
    duplicate.update!(latest_version: version)

    result = ImportDryRunValidator.new(
      project:,
      entries: [{ source_path: "docs/reference.docx", title: "Operation Manual" }]
    ).call

    hash = described_class.new(result).call

    candidate_reasons = hash[:items].first[:duplicate_candidates].map { _1[:reason] }
    expect(candidate_reasons).to contain_exactly(:same_source_basename, :same_title)
    same_title = hash[:items].first[:duplicate_candidates].find { _1[:reason] == :same_title }
    expect(same_title[:documents].first).to include(public_id: duplicate.public_id, title: "Operation Manual")
  end

  it "renders an empty result" do
    result = ImportDryRunValidator::Result.new(items: [])

    hash = described_class.new(result).call

    expect(hash[:valid]).to be(true)
    expect(hash[:summary]).to include(total: 0, create_count: 0, update_count: 0)
    expect(hash[:items]).to eq([])
  end
end
