require "rails_helper"

RSpec.describe DocumentBulkEditExecutor do
  let(:actor) { create(:user, :admin) }
  let(:project) { create(:project) }

  def attach_tag(document, name)
    tag = DocumentTag.find_or_create_by!(normalized_name: DocumentTag.normalize(name)) do |record|
      record.name = name
    end
    DocumentTagging.create!(document:, document_tag: tag, sort_order: document.document_taggings.count)
  end

  it "applies previewed changes and marks the dry-run confirmed" do
    document = create(:document, project:, category: :spec, visibility_policy: :restricted_external, importance_level: :normal, recommended_sort_order: 0)
    version = create(:document_version, document:, snapshot_kind: "current")
    document.update!(latest_version: version)
    attach_tag(document, "Legacy")

    dry_run = DocumentBulkEditPreview.new(
      actor:,
      documents: [document],
      changes: {
        document_attributes: {
          category: "manual",
          visibility_policy: "public_with_login",
          importance_level: "critical",
          recommended_sort_order: 7
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
    ).call.bulk_edit_dry_run

    result = described_class.new(dry_run:, actor:).call

    expect(result.success_count).to eq(1)
    expect(result.failure_count).to eq(0)
    expect(document.reload.category).to eq("manual")
    expect(document.visibility_policy).to eq("public_with_login")
    expect(document.importance_level).to eq("critical")
    expect(document.recommended_sort_order).to eq(7)
    expect(document.archived?).to eq(true)
    expect(document.latest_version.reload.snapshot_kind).to eq("submitted")
    expect(document.latest_version.published_from).to be_present
    expect(document.document_tags.order(:normalized_name).pluck(:name)).to eq(["Current"])
    expect(dry_run.reload).to be_confirmed
    expect(dry_run.summary_json.dig("execution", "success_count") || dry_run.summary_json.dig(:execution, :success_count)).to eq(1)
  end

  it "records a failure when a targeted document no longer exists" do
    document = create(:document, project:)
    dry_run = DocumentBulkEditPreview.new(
      actor:,
      documents: [document],
      changes: {
        document_attributes: { category: "manual" }
      }
    ).call.bulk_edit_dry_run
    document.destroy!

    result = described_class.new(dry_run:, actor:).call

    expect(result.failure_count).to eq(1)
    expect(result.items.first.errors).to include("document no longer exists")
    expect(dry_run.reload).to be_failed
  end
end
