require "rails_helper"

RSpec.describe ProjectConsentSetting, type: :model do
  let(:project) { create(:project) }
  let(:term) { create(:consent_term, consent_scope: :project) }

  it "requires a unique term per project and timing" do
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)
    duplicate = build(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:consent_term_id]).to be_present
  end

  it "uses public_id for routes" do
    setting = create(:project_consent_setting, project:, consent_term: term)

    expect(setting.to_param).to eq(setting.public_id)
  end
end
