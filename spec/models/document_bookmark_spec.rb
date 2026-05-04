require "rails_helper"

RSpec.describe DocumentBookmark, type: :model do
  let(:user) { create(:user, :internal) }
  let(:document) { create(:document) }

  it "allows one favorite and one read-later bookmark for the same document" do
    favorite = create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    read_later = create(:document_bookmark, user:, document:, bookmark_type: :read_later)

    expect(favorite).to be_persisted
    expect(read_later).to be_persisted
  end

  it "does not allow duplicate bookmarks of the same type" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    duplicate = build(:document_bookmark, user:, document:, bookmark_type: :favorite)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:document_id]).to be_present
  end

  it "uses public_id for routes" do
    bookmark = create(:document_bookmark, user:, document:)

    expect(bookmark.to_param).to eq(bookmark.public_id)
  end
end
