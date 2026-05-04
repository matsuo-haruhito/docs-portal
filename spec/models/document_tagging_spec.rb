require "rails_helper"

RSpec.describe DocumentTagging, type: :model do
  it "does not allow a negative sort order" do
    tag = DocumentTag.create!(name: "重要", normalized_name: "重要")

    tagging = described_class.new(
      document: create(:document),
      document_tag: tag,
      sort_order: -1
    )

    expect(tagging).not_to be_valid
    expect(tagging.errors[:sort_order]).to be_present
  end
end
