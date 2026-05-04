require "rails_helper"

RSpec.describe DocumentFile, type: :model do
  let(:version) { create(:document_version) }

  def build_file(attributes = {})
    described_class.new(
      {
        document_version: version,
        file_name: "manual.pdf",
        content_type: "application/pdf",
        storage_key: "spec/manual.pdf",
        file_size: 12,
        sort_order: 0
      }.merge(attributes)
    )
  end

  it "allows non-negative file size and sort order" do
    file = build_file(file_size: 0, sort_order: 0)

    expect(file).to be_valid
  end

  it "does not allow a negative file size" do
    file = build_file(file_size: -1)

    expect(file).not_to be_valid
    expect(file.errors[:file_size]).to be_present
  end

  it "does not allow a negative sort order" do
    file = build_file(sort_order: -1)

    expect(file).not_to be_valid
    expect(file.errors[:sort_order]).to be_present
  end
end
