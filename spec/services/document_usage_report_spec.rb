require "rails_helper"

RSpec.describe DocumentUsageReport do
  let(:project) { create(:project) }
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  def create_document(title:, slug:)
    create(:document, project:, title:, slug:)
  end

  it "summarizes document views, downloads, and read confirmations" do
    document = create_document(title: "Manual", slug: "manual")
    unused = create_document(title: "Unused", slug: "unused")
    create(:access_log, project:, document:, user:, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user:, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 11, 0, 0))
    create(:access_log, project:, document:, user:, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user:, confirmed_at: Time.zone.local(2026, 5, 1, 13, 0, 0))

    result = described_class.new(project:).call

    row = result.rows.find { _1.document == document }
    unused_row = result.rows.find { _1.document == unused }
    expect(row.view_count).to eq(2)
    expect(row.download_count).to eq(1)
    expect(row.read_confirmation_count).to eq(1)
    expect(row.last_accessed_at).to eq(Time.zone.local(2026, 5, 1, 12, 0, 0))
    expect(row).to be_used
    expect(unused_row).not_to be_used
    expect(result.used_documents).to eq([document])
    expect(result.unused_documents).to eq([unused])
    expect(result.total_views).to eq(2)
    expect(result.total_downloads).to eq(1)
    expect(result.total_read_confirmations).to eq(1)
  end

  it "filters usage by time range" do
    document = create_document(title: "Manual", slug: "manual")
    create(:access_log, project:, document:, user:, company:, action_type: :view, accessed_at: Time.zone.local(2026, 4, 30, 23, 59, 0))
    create(:access_log, project:, document:, user:, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user:, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    result = described_class.new(
      project:,
      from: Time.zone.local(2026, 5, 1, 0, 0, 0),
      to: Time.zone.local(2026, 5, 1, 23, 59, 59)
    ).call

    row = result.rows.first
    expect(row.view_count).to eq(0)
    expect(row.download_count).to eq(1)
    expect(row.read_confirmation_count).to eq(0)
  end

  it "supports a narrower document scope" do
    included = create_document(title: "Included", slug: "included")
    create_document(title: "Excluded", slug: "excluded")

    result = described_class.new(project:, scope: Document.where(id: included.id)).call

    expect(result.rows.map(&:document)).to eq([included])
  end
end
