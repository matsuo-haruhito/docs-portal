require "rails_helper"

RSpec.describe DocumentUsageReport do
  let(:project) { create(:project) }
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }

  def create_document(title:, slug:)
    create(:document, project:, title:, slug:)
  end

  def captured_sql
    queries = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      next if payload[:name].in?(["SCHEMA", "TRANSACTION"])

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      yield
    end

    queries
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

  it "loads access logs and read confirmations once for the selected documents" do
    manual = create_document(title: "Manual", slug: "manual")
    guide = create_document(title: "Guide", slug: "guide")
    checklist = create_document(title: "Checklist", slug: "checklist")
    other_project = create(:project)
    other_project_document = create(:document, project: other_project, title: "Other", slug: "other")
    from = Time.zone.local(2026, 5, 1, 0, 0, 0)
    to = Time.zone.local(2026, 5, 31, 23, 59, 59)

    create(:access_log, project:, document: manual, user:, company:, action_type: :view, accessed_at: from + 1.hour)
    create(:access_log, project:, document: manual, user:, company:, action_type: :download, accessed_at: from + 2.hours)
    create(:access_log, project:, document: guide, user:, company:, action_type: :view, accessed_at: from + 3.hours)
    create(:access_log, project:, document: checklist, user:, company:, action_type: :view, accessed_at: from - 1.day)
    create(:access_log, project: other_project, document: other_project_document, user:, company:, action_type: :view, accessed_at: from + 4.hours)
    create(:read_confirmation, document: guide, user:, confirmed_at: from + 5.hours)
    create(:read_confirmation, document: checklist, user:, confirmed_at: from - 1.day)

    result = nil
    queries = captured_sql do
      result = described_class.new(project:, from:, to:).call
    end

    rows_by_slug = result.rows.index_by { |row| row.document.slug }
    expect(rows_by_slug.keys).to eq(["checklist", "guide", "manual"])
    expect(rows_by_slug["manual"].view_count).to eq(1)
    expect(rows_by_slug["manual"].download_count).to eq(1)
    expect(rows_by_slug["manual"].read_confirmation_count).to eq(0)
    expect(rows_by_slug["guide"].view_count).to eq(1)
    expect(rows_by_slug["guide"].download_count).to eq(0)
    expect(rows_by_slug["guide"].read_confirmation_count).to eq(1)
    expect(rows_by_slug["checklist"].view_count).to eq(0)
    expect(rows_by_slug["checklist"].read_confirmation_count).to eq(0)

    access_log_queries = queries.grep(/FROM "access_logs"/)
    read_confirmation_queries = queries.grep(/FROM "read_confirmations"/)

    expect(access_log_queries.size).to eq(1)
    expect(read_confirmation_queries.size).to eq(1)
  end

  it "supports a narrower document scope" do
    included = create_document(title: "Included", slug: "included")
    create_document(title: "Excluded", slug: "excluded")

    result = described_class.new(project:, scope: Document.where(id: included.id)).call

    expect(result.rows.map(&:document)).to eq([included])
  end
end
