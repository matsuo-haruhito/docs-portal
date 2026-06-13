require "rails_helper"

RSpec.describe DocumentDeliveryLogs::FailureAlertCandidates do
  describe "#call" do
    it "returns candidates whose latest delivery logs are consecutive failures at the threshold" do
      older_success = create_delivery_log(status: :sent, created_at: 4.hours.ago)
      failures = [
        create_delivery_log(status: :failed, error_message: "third failure", created_at: 1.hour.ago),
        create_delivery_log(status: :failed, error_message: "second failure", created_at: 2.hours.ago),
        create_delivery_log(status: :failed, error_message: "first failure", created_at: 3.hours.ago)
      ]

      candidates = described_class.new.call

      expect(candidates.size).to eq(1)
      candidate = candidates.first
      expect(candidate.project_id).to eq(project.id)
      expect(candidate.delivery_type).to eq("portal_link")
      expect(candidate.to_addresses).to eq("client@example.com")
      expect(candidate.subject).to eq("Document delivery")
      expect(candidate.failure_count).to eq(3)
      expect(candidate.logs).to eq(failures)
      expect(candidate.latest_error_message).to eq("third failure")
      expect(candidate.last_failed_at.to_i).to eq(failures.first.updated_at.to_i)
      expect(candidate.logs).not_to include(older_success)
    end

    it "does not return a candidate when a later sent log breaks the failure streak" do
      create_delivery_log(status: :sent, created_at: 30.minutes.ago)
      create_delivery_log(status: :failed, created_at: 1.hour.ago)
      create_delivery_log(status: :failed, created_at: 2.hours.ago)
      create_delivery_log(status: :failed, created_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "keeps unrelated delivery identities separated" do
      create_delivery_log(status: :failed, subject: "Document delivery", created_at: 1.hour.ago)
      create_delivery_log(status: :failed, subject: "Document delivery", created_at: 2.hours.ago)
      create_delivery_log(status: :failed, subject: "Other delivery", created_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "allows the threshold and relation to be scoped by callers" do
      matching = create_delivery_log(status: :failed, delivery_type: :portal_link, created_at: 1.hour.ago)
      create_delivery_log(status: :failed, delivery_type: :attachment, created_at: 30.minutes.ago)

      candidates = described_class.new(
        relation: DocumentDeliveryLog.portal_link,
        threshold: 1
      ).call

      expect(candidates.size).to eq(1)
      expect(candidates.first.logs).to eq([matching])
      expect(candidates.first.delivery_type).to eq("portal_link")
    end

    it "applies a lookback limit to the ordered relation before grouping" do
      matching = create_delivery_log(status: :failed, created_at: 1.hour.ago)
      relation = instance_double(ActiveRecord::Relation)
      included_relation = instance_double(ActiveRecord::Relation)
      ordered_relation = instance_double(ActiveRecord::Relation)

      allow(relation).to receive(:includes).with(:project).and_return(included_relation)
      allow(included_relation).to receive(:order)
        .with(created_at: :desc, id: :desc)
        .and_return(ordered_relation)
      allow(ordered_relation).to receive(:limit).with(1).and_return([matching])

      candidates = described_class.new(
        relation: relation,
        threshold: 1,
        lookback_limit: 1
      ).call

      expect(ordered_relation).to have_received(:limit).with(1)
      expect(candidates.map(&:subject)).to eq(["Document delivery"])
    end

    it "orders candidates by latest failure time and applies the limit" do
      newest = create_failure_streak(subject: "newest", created_at: 10.minutes.ago)
      create_failure_streak(subject: "middle", created_at: 20.minutes.ago)
      create_failure_streak(subject: "oldest", created_at: 30.minutes.ago)

      candidates = described_class.new(limit: 2).call

      expect(candidates.map(&:subject)).to eq(["newest", "middle"])
      expect(candidates.first.logs.first).to eq(newest)
    end
  end

  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:) }
  let(:sender) { create(:user, :internal) }

  def create_failure_streak(subject:, created_at:)
    latest = create_delivery_log(status: :failed, subject: subject, created_at: created_at)
    create_delivery_log(status: :failed, subject: subject, created_at: created_at - 1.minute)
    create_delivery_log(status: :failed, subject: subject, created_at: created_at - 2.minutes)
    latest
  end

  def create_delivery_log(status:, delivery_type: :portal_link, to_addresses: "client@example.com", subject: "Document delivery", created_at:, error_message: "boom")
    create(
      :document_delivery_log,
      project: project,
      document: document,
      sender: sender,
      status: status,
      delivery_type: delivery_type,
      to_addresses: to_addresses,
      subject: subject,
      error_message: status.to_sym == :failed ? error_message : nil
    ).tap do |log|
      log.update_columns(created_at: created_at, updated_at: created_at)
    end
  end
end
