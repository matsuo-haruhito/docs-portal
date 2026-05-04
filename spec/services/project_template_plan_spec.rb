require "rails_helper"

RSpec.describe ProjectTemplatePlan do
  let(:project) { create(:project, code: "TPL") }

  it "plans creation for missing template documents" do
    result = described_class.new(project:).call

    expect(result.project).to eq(project)
    expect(result.template.name).to eq("standard_project")
    expect(result.creates.size).to eq(result.items.size)
    expect(result.skips).to be_empty
  end

  it "skips existing documents by source path" do
    document = create(:document, project:, title: "要件定義 README", slug: "01-readme-md")
    version = create(:document_version, document:, source_relative_path: "01_要件定義/README.md")
    document.update!(latest_version: version)

    result = described_class.new(project:).call

    skipped = result.skips.find { _1.existing_document == document }
    expect(skipped).to be_present
    expect(skipped.definition.source_path).to eq("01_要件定義/README.md")
  end
end
