require "rails_helper"

RSpec.describe ReadConfirmation, type: :model do
  let(:user) { create(:user, :internal) }
  let(:document) { create(:document) }

  it "sets confirmed_at on create" do
    confirmation = described_class.create!(user:, document:)

    expect(confirmation.confirmed_at).to be_present
  end

  it "does not allow duplicate confirmations for the same user and document" do
    create(:read_confirmation, user:, document:)
    duplicate = build(:read_confirmation, user:, document:)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:document_id]).to be_present
  end

  it "uses public_id for routes" do
    confirmation = create(:read_confirmation, user:, document:)

    expect(confirmation.to_param).to eq(confirmation.public_id)
  end
end
