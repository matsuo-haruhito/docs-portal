require "rails_helper"

RSpec.describe ProjectTemplatePlanHash do
  let(:project) { create(:project, code: "TPL", name: "Template Project") }

  it "renders summary and items" do
    plan = ProjectTemplatePlan.new(project:).call
    hash = described_class.new(plan).call

    expect(hash[:project]).to include(code: "TPL", name: "Template Project")
    expect(hash[:template]).to include(name: "standard_project")
    expect(hash[:summary]).to include(total: plan.items.size, create_count: plan.creates.size, skip_count: 0)
    expect(hash[:items].first).to include(action: :create, existing_document_id: nil)
  end

  it "includes existing document ids for skipped items" do
    document = create(:document, project:, title: "Template Index", slug: "01-readme-md")
    version = create(:document_version, document:, source_relative_path: "01_要件定義/README.md")
    document.update!(latest_version: version)

    hash = described_class.new(ProjectTemplatePlan.new(project:).call).call
    skipped = hash[:items].find { |item| item[:action] == :skip }

    expect(skipped).to include(existing_document_id: document.public_id)
  end
end
