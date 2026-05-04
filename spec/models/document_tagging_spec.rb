require "rails_helper"

RSpec.describe DocumentTagging, type: :model do
  it "does not allow a negative sort order" do
    tagging = described_class.new(
      document: create(:document),
      document_tag: create(:document_tag),
      sort_order: -1
    )

    expect(tagging).not_to be_valid
    expect(tagging.errors[:sort_order]).to be_present
  end
end
