require "rails_helper"

RSpec.describe DocumentUsageReportHash do
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  it "renders summary and document rows as a hash" do
    document = create(:document, project:, title: "Manual", slug: "manual", category: :manual, document_kind: :pdf, visibility_policy: :restricted_external)
    unused = create(:document, project:, title: "Unused", slug: "unused")
    time = Time.zone.local(2026, 5, 1, 12, 0, 0)
    create(:access_log, project:, document:, user:, company:, action_type: :view, accessed_at: time)
    create(:access_log, project:, document:, user:, company:, action_type: :download, accessed_at: time + 1.hour)
    create(:read_confirmation, document:, user:, confirmed_at: time + 2.hours)

    hash = described_class.new(DocumentUsageReport.new(project:).call).call

    expect(hash[:project]).to include(code: "USAGE", name: "Usage Project")
    expect(hash[:summary]).to include(document_count: 2, used_document_count: 1, unused_document_count: 1)
    expect(hash[:summary]).to include(total_views: 1, total_downloads: 1, total_read_confirmations: 1)

    manual = hash[:documents].find { |row| row[:public_id] == document.public_id }
    expect(manual).to include(title: "Manual", slug: "manual", used: true)
    expect(manual).to include(view_count: 1, download_count: 1, read_confirmation_count: 1)
    expect(manual[:last_accessed_at]).to eq((time + 1.hour).iso8601)

    unused_row = hash[:documents].find { |row| row[:public_id] == unused.public_id }
    expect(unused_row).to include(used: false, view_count: 0, download_count: 0, read_confirmation_count: 0)
    expect(unused_row[:last_accessed_at]).to be_nil
  end
end
