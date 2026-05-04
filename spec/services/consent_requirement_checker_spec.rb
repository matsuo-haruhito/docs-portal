require "rails_helper"

RSpec.describe ConsentRequirementChecker do
  let(:user) { create(:user, :external) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }
  let(:file) { create(:document_file, document_version: version) }

  it "reports missing global consent" do
    term = create(:consent_term, consent_scope: :global)

    result = described_class.new(user:, target: document).call

    expect(result).to be_required
    expect(result).not_to be_satisfied
    expect(result.missing_terms).to eq([term])
  end

  it "is satisfied when the user has global consent" do
    term = create(:consent_term, consent_scope: :global)
    create(:user_consent, user:, consent_term: term)

    result = described_class.new(user:, target: document).call

    expect(result).to be_satisfied
    expect(result.missing_terms).to be_empty
  end

  it "applies project terms to documents in the project" do
    term = create(:consent_term, consent_scope: :project)
    create(:user_consent, user:, consent_term: term, target: project)

    result = described_class.new(user:, target: document).call

    expect(result.required_terms).to include(term)
    expect(result).to be_satisfied
  end

  it "applies document terms to document files through their document" do
    term = create(:consent_term, consent_scope: :document)
    create(:user_consent, user:, consent_term: term, target: document)

    result = described_class.new(user:, target: file).call

    expect(result.required_terms).to include(term)
    expect(result).to be_satisfied
  end

  it "filters terms by requirement timing" do
    first_view = create(:consent_term, consent_scope: :global, requirement_timing: :first_view)
    every_download = create(:consent_term, consent_scope: :global, requirement_timing: :every_download)

    result = described_class.new(user:, target: file, timing: :every_download).call

    expect(result.required_terms).to eq([every_download])
    expect(result.required_terms).not_to include(first_view)
  end
end
