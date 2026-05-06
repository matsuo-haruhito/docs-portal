require "rails_helper"

RSpec.describe ConsentRequirementChecker do
  let(:user) { create(:user, :external) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }
  let(:file) { create(:document_file, document_version: version) }

  it "reports missing global consent and is satisfied after global consent" do
    term = create(:consent_term, title: "Global Terms", consent_scope: :global, requirement_timing: :first_view)

    result = described_class.new(user:, target: document, timing: :first_view).call

    expect(result).to be_required
    expect(result).not_to be_satisfied
    expect(result.missing_terms).to eq([term])

    create(:user_consent, user:, consent_term: term, target: nil, consent_term_version_label: term.version_label)

    result = described_class.new(user:, target: document, timing: :first_view).call
    expect(result).to be_satisfied
  end

  it "requires enabled project first access terms until the user consents" do
    term = create(:consent_term, title: "Project NDA", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    result = described_class.new(user:, target: document, timing: :first_view).call

    expect(result.target).to eq(project)
    expect(result.missing_terms).to eq([term])

    create(:user_consent, user:, consent_term: term, target: project, consent_term_version_label: "v1")

    result = described_class.new(user:, target: document, timing: :first_view).call
    expect(result).to be_satisfied
  end

  it "requires re-consent when the active project term version changes" do
    old_term = create(:consent_term, title: "Project NDA", consent_scope: :project, version_label: "v1", active: false)
    new_term = create(:consent_term, title: "Project NDA", consent_scope: :project, version_label: "v2")
    create(:project_consent_setting, project:, consent_term: new_term, required_on: :first_access)
    create(:user_consent, user:, consent_term: old_term, target: project, consent_term_version_label: "v1")

    result = described_class.new(user:, target: project, timing: :first_view).call

    expect(result.missing_terms).to eq([new_term])
  end

  it "checks download-only project requirements separately" do
    access_term = create(:consent_term, title: "Access Terms", consent_scope: :project)
    download_term = create(:consent_term, title: "Download Terms", consent_scope: :download)
    create(:project_consent_setting, project:, consent_term: access_term, required_on: :first_access)
    create(:project_consent_setting, project:, consent_term: download_term, required_on: :download)

    access_result = described_class.new(user:, target: file, timing: :first_view).call
    download_result = described_class.new(user:, target: file, timing: :download).call

    expect(access_result.missing_terms).to eq([access_term])
    expect(download_result.missing_terms).to eq([download_term])
  end

  it "ignores disabled project consent settings" do
    term = create(:consent_term, title: "Disabled Terms", consent_scope: :project)
    create(:project_consent_setting, project:, consent_term: term, enabled: false)

    result = described_class.new(user:, target: project, timing: :first_view).call

    expect(result).to be_satisfied
  end
end
