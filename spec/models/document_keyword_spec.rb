require "rails_helper"

RSpec.describe DocumentKeyword, type: :model do
  it "does not allow a negative sort order" do
    keyword = described_class.new(
      document: create(:document),
      keyword: "要件定義",
      sort_order: -1
    )

    expect(keyword).not_to be_valid
    expect(keyword.errors[:sort_order]).to be_present
  end
end
