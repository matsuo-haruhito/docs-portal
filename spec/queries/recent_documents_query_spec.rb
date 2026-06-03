require "rails_helper"

RSpec.describe RecentDocumentsQuery do
  describe "#call" do
    subject(:recent_documents) { described_class.new(user:, limit:).call }

    let(:user) { create(:user, :internal) }
    let(:limit) { 10 }
    let(:base_time) { Time.zone.local(2026, 1, 15, 12, 0, 0) }

    it "uses only the current user's view logs with document ids" do
      current_user_document = create(:document, title: "Current user viewed")
      other_user_document = create(:document, title: "Other user viewed")
      downloaded_document = create(:document, title: "Downloaded")

      create(:access_log, user:, document: current_user_document, action_type: :view, accessed_at: base_time)
      create(:access_log, user: create(:user, :internal), document: other_user_document, action_type: :view, accessed_at: base_time + 2.minutes)
      create(:access_log, user:, document: downloaded_document, action_type: :download, accessed_at: base_time + 3.minutes)
      create(:access_log, user:, document: nil, action_type: :view, accessed_at: base_time + 4.minutes)

      expect(recent_documents).to eq([current_user_document])
    end

    it "keeps one entry per document and orders by the latest view log" do
      earlier_latest_document = create(:document, title: "Earlier latest")
      newest_document = create(:document, title: "Newest")
      duplicated_document = create(:document, title: "Duplicated")

      create(:access_log, user:, document: duplicated_document, accessed_at: base_time)
      create(:access_log, user:, document: earlier_latest_document, accessed_at: base_time + 1.minute)
      create(:access_log, user:, document: duplicated_document, accessed_at: base_time + 3.minutes)
      create(:access_log, user:, document: newest_document, accessed_at: base_time + 5.minutes)

      expect(recent_documents).to eq([newest_document, duplicated_document, earlier_latest_document])
    end

    it "uses access log id as the tie-breaker when accessed_at is the same" do
      first_document = create(:document, title: "First")
      second_document = create(:document, title: "Second")

      create(:access_log, user:, document: first_document, accessed_at: base_time)
      create(:access_log, user:, document: second_document, accessed_at: base_time)

      expect(recent_documents).to eq([second_document, first_document])
    end

    it "excludes documents that are no longer viewable by the user" do
      viewable_document = create(:document, title: "Viewable")
      archived_document = create(:document, title: "Archived", archived_at: 1.day.ago)

      create(:access_log, user:, document: archived_document, accessed_at: base_time + 2.minutes)
      create(:access_log, user:, document: viewable_document, accessed_at: base_time)

      expect(recent_documents).to eq([viewable_document])
    end

    it "returns no documents for inactive users" do
      inactive_user = create(:user, :internal, active: false)
      document = create(:document)
      create(:access_log, user: inactive_user, document:, accessed_at: base_time)

      results = described_class.new(user: inactive_user).call

      expect(results).to be_empty
    end

    it "falls back to the default limit for nil, zero, or negative limits" do
      documents = Array.new(11) do |index|
        document = create(:document, title: "Document #{index}")
        create(:access_log, user:, document:, accessed_at: base_time + index.minutes)
        document
      end
      expected_default_window = documents.last(10).reverse

      expect(described_class.new(user:, limit: nil).call).to eq(expected_default_window)
      expect(described_class.new(user:, limit: 0).call).to eq(expected_default_window)
      expect(described_class.new(user:, limit: -1).call).to eq(expected_default_window)
    end
  end
end
