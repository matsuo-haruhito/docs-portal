require "rails_helper"

RSpec.describe UserConsent, type: :model do
  let(:user) { create(:user, :internal) }
  let(:term) { create(:consent_term) }
  let(:project) { create(:project) }

  it "sets consented_at on create" do
    consent = described_class.create!(user:, consent_term: term)

    expect(consent.consented_at).to be_present
  end

  it "does not allow duplicate consents for the same user, term, and target" do
    create(:user_consent, user:, consent_term: term, target: project)
    duplicate = build(:user_consent, user:, consent_term: term, target: project)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:consent_term_id]).to be_present
  end

  it "uses public_id for routes" do
    consent = create(:user_consent, user:, consent_term: term)

    expect(consent.to_param).to eq(consent.public_id)
  end
end
