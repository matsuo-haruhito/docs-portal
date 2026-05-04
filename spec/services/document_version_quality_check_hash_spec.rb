require "rails_helper"

RSpec.describe DocumentVersionQualityCheckHash do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1", status: :published, search_body_text: "internal_only") }

  it "renders quality check result as a stable hash" do
    result = DocumentVersionQualityChecker.new(version).call

    hash = described_class.new(result).call

    expect(hash[:valid]).to eq(result.pass?)
    expect(hash[:document_version]).to include(
      public_id: version.public_id,
      version_label: "v1",
      status: "published"
    )
    expect(hash[:document_version][:document]).to include(
      public_id: document.public_id,
      title: "Manual",
      slug: "manual",
      visibility_policy: "restricted_external"
    )
    expect(hash[:summary]).to include(
      error_count: result.errors.size,
      warning_count: result.warnings.size,
      info_count: result.infos.size
    )
    expect(hash[:checks]).to include(
      include(
        key: :internal_only_text,
        severity: :warning,
        message: "Document contains internal-only wording"
      )
    )
  end

  it "renders all checks with key, severity, message, and detail" do
    result = DocumentVersionQualityChecker.new(version).call

    checks = described_class.new(result).call.fetch(:checks)

    expect(checks).not_to be_empty
    checks.each do |check|
      expect(check.keys).to contain_exactly(:key, :severity, :message, :detail)
    end
  end
end
