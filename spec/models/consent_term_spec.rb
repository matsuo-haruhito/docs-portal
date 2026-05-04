require "rails_helper"

RSpec.describe ConsentTerm, type: :model do
  it "requires title, body, and version label" do
    term = build(:consent_term, title: "", body: "", version_label: "")

    expect(term).not_to be_valid
    expect(term.errors[:title]).to be_present
    expect(term.errors[:body]).to be_present
    expect(term.errors[:version_label]).to be_present
  end

  it "does not allow duplicate title and version label" do
    create(:consent_term, title: "Terms", version_label: "v1")
    duplicate = build(:consent_term, title: "Terms", version_label: "v1")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:version_label]).to be_present
  end

  it "uses public_id for routes" do
    term = create(:consent_term)

    expect(term.to_param).to eq(term.public_id)
  end
end
