require "rails_helper"

RSpec.describe DocumentBulkEditPlan do
  let(:actor) { create(:user, :admin) }
  let(:project) { create(:project) }

  def attach_tag(document, name)
    tag = DocumentTag.find_or_create_by!(normalized_name: DocumentTag.normalize(name)) do |record|
      record.name = name
    end
    DocumentTagging.create!(document:, document_tag: tag, sort_order: document.document_taggings.count)
  end

  it "previews supported document, version, tag, and archive changes" do
    document = create(:document, project:, category: :spec, visibility_policy: :restricted_external, importance_level: :normal, recommended_sort_order: 0)
    version = create(:document_version, document:, snapshot_kind: "current")
    document.update!(latest_version: version)
    attach_tag(document, "Legacy")

    result = described_class.new(
      actor:,
      documents: [document],
      changes: {
        document_attributes: {
          category: "manual",
          visibility_policy: "public_with_login",
          importance_level: "critical",
          recommended_sort_order: 5
        },
        latest_version_attributes: {
          snapshot_kind: "submitted",
          published_from: "2026-05-08 09:00",
          published_until: "2026-05-09 09:00"
        },
        add_tag_names: ["Current"],
        remove_tag_names: ["Legacy"],
        archive: true
      }
    ).call

    item = result.items.first
    expect(result).to be_valid
    expect(item.after.dig(:document, :category)).to eq("manual")
    expect(item.after.dig(:document, :visibility_policy)).to eq("public_with_login")
    expect(item.after.dig(:document, :importance_level)).to eq("critical")
    expect(item.after.dig(:document, :recommended_sort_order)).to eq(5)
    expect(item.after.dig(:document, :archived)).to eq(true)
    expect(item.after.dig(:latest_version, :snapshot_kind)).to eq("submitted")
    expect(item.after.dig(:latest_version, :published_from)).to be_present
    expect(item.after[:tag_names]).to eq(["Current"])
    expect(item.changed_fields).to include("category", "visibility_policy", "importance_level", "recommended_sort_order", "latest_version.snapshot_kind", "latest_version.published_from", "latest_version.published_until", "tag_names", "archived")
  end

  it "reports latest version changes as invalid when the document has no latest version" do
    document = create(:document, project:)

    result = described_class.new(
      actor:,
      documents: [document],
      changes: {
        latest_version_attributes: { snapshot_kind: "submitted" }
      }
    ).call

    item = result.items.first
    expect(result).not_to be_valid
    expect(item.errors).to include("latest_version_attributes require a latest version")
  end

  it "rejects unsupported callers and empty changes" do
    document = create(:document, project:)
    external_actor = create(:user, :external)

    result = described_class.new(actor: external_actor, documents: [document], changes: {}).call

    expect(result).not_to be_valid
    expect(result.errors).to include("bulk edit requires an admin actor")
  end

  it "deduplicates normalized tag changes and rejects conflicting operations" do
    document = create(:document, project:)

    result = described_class.new(
      actor:,
      documents: [document],
      changes: {
        add_tag_names: ["Policy", " policy "],
        remove_tag_names: ["POLICY"]
      }
    ).call

    expect(result).not_to be_valid
    expect(result.changes[:add_tag_names]).to eq(["Policy"])
    expect(result.changes[:remove_tag_names]).to eq(["POLICY"])
    expect(result.errors).to include("the same tag cannot be added and removed in one operation: policy")
  end
end
