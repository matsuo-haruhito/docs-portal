require "rails_helper"

RSpec.describe DocumentBulkEditPreview do
  let(:actor) { create(:user, :admin) }
  let(:project) { create(:project) }

  it "persists a bulk edit dry-run preview" do
    document = create(:document, project:)

    result = described_class.new(
      actor:,
      documents: [document],
      changes: {
        document_attributes: { category: "manual" }
      }
    ).call

    dry_run = result.bulk_edit_dry_run
    expect(dry_run).to be_persisted
    expect(dry_run.project).to eq(project)
    expect(dry_run.target_document_ids).to eq([document.id])
    expect(dry_run.summary_json.dig("preview", "total_count") || dry_run.summary_json.dig(:preview, :total_count)).to eq(1)
    expect(dry_run.result_json["preview_items"].size).to eq(1)
  end
end
