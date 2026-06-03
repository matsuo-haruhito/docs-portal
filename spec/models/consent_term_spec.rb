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

  it "allows the same version label for different titles" do
    create(:consent_term, title: "Project Terms", version_label: "v1")
    term = build(:consent_term, title: "Download Terms", version_label: "v1")

    expect(term).to be_valid
  end

  it "returns only active terms from active_only" do
    active_term = create(:consent_term, title: "Active Terms", active: true)
    inactive_term = create(:consent_term, title: "Inactive Terms", active: false)

    expect(described_class.active_only).to contain_exactly(active_term)
    expect(described_class.active_only).not_to include(inactive_term)
  end

  it "uses public_id for routes" do
    term = create(:consent_term)

    expect(term.to_param).to eq(term.public_id)
  end
end
