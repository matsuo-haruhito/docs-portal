require "rails_helper"

RSpec.describe BulkEditDryRun, type: :model do
  it "is valid with persisted preview payloads" do
    dry_run = build(:bulk_edit_dry_run)

    expect(dry_run).to be_valid
  end

  it "requires warnings_json and errors_json to be present" do
    dry_run = build(:bulk_edit_dry_run, warnings_json: nil, errors_json: nil)

    expect(dry_run).not_to be_valid
    expect(dry_run.errors[:warnings_json]).to be_present
    expect(dry_run.errors[:errors_json]).to be_present
  end

  it "returns normalized document ids" do
    dry_run = build(:bulk_edit_dry_run, target_document_ids: ["1", 2, 2])

    expect(dry_run.document_ids).to eq([1, 2])
  end
end
