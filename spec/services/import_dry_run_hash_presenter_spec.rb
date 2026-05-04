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

  it "renders an empty result" do
    result = ImportDryRunValidator::Result.new(items: [])

    hash = described_class.new(result).call

    expect(hash[:valid]).to be(true)
    expect(hash[:summary]).to include(total: 0, create_count: 0, update_count: 0)
    expect(hash[:items]).to eq([])
  end
end
