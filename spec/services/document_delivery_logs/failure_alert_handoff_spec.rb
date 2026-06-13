require "rails_helper"

RSpec.describe DocumentDeliveryLogs::FailureAlertHandoff do
  describe "#call" do
    it "returns handoff payload entries for consecutive failure candidates" do
      failures = [
        create_delivery_log(status: :failed, error_message: "third failure", created_at: 1.hour.ago),
        create_delivery_log(status: :failed, error_message: "second failure", created_at: 2.hours.ago),
        create_delivery_log(status: :failed, error_message: "first failure", created_at: 3.hours.ago)
      ]

      entries = described_class.new.call

      expect(entries.size).to eq(1)
      entry = entries.first
      expect(entry.project_id).to eq(project.id)
      expect(entry.project_code).to eq("DLV1")
      expect(entry.project_name).to eq("Delivery Project")
      expect(entry.delivery_type).to eq("portal_link")
      expect(entry.recipient_preview).to eq("client@example.com")
      expect(entry.subject_preview).to eq("Document delivery")
      expect(entry.failure_count).to eq(3)
      expect(entry.last_failed_at.to_i).to eq(failures.first.updated_at.to_i)
      expect(entry.latest_error_message).to eq("third failure")
      expect(entry.failed_delivery_logs_path).to eq("/document_delivery_logs?delivery_type=portal_link&q=Document+delivery&status=failed")
      expect(entry.runbook_path).to eq("docs/外部送付履歴継続失敗候補runbook.md")
      expect(entry.to_h).to include(
        identity: {
          project_id: project.id,
          delivery_type: "portal_link",
          to_addresses: "client@example.com",
          subject: "Document delivery"
        },
        project_code: "DLV1",
        failure_count: 3,
        latest_error_message: "third failure"
      )
    end

    it "returns an empty payload when there are no candidates" do
      create_delivery_log(status: :sent, created_at: 30.minutes.ago)
      create_delivery_log(status: :failed, created_at: 1.hour.ago)
      create_delivery_log(status: :failed, created_at: 2.hours.ago)
      create_delivery_log(status: :failed, created_at: 3.hours.ago)

      expect(described_class.new.call).to be_empty
    end

    it "keeps the caller controlled candidate scope and threshold" do
      matching = create_delivery_log(status: :failed, delivery_type: :portal_link, created_at: 1.hour.ago)
      create_delivery_log(status: :failed, delivery_type: :attachment, created_at: 30.minutes.ago)

      entries = described_class.new(
        relation: DocumentDeliveryLog.portal_link,
        threshold: 1
      ).call

      expect(entries.size).to eq(1)
      expect(entries.first.delivery_type).to eq("portal_link")
      expect(entries.first.last_failed_at.to_i).to eq(matching.updated_at.to_i)
    end

    it "passes the lookback limit through to the candidate query" do
      matching = create_delivery_log(status: :failed, created_at: 1.hour.ago)
      relation = instance_double(ActiveRecord::Relation)
      included_relation = instance_double(ActiveRecord::Relation)
      ordered_relation = instance_double(ActiveRecord::Relation)

      allow(relation).to receive(:includes).with(:project).and_return(included_relation)
      allow(included_relation).to receive(:order)
        .with(created_at: :desc, id: :desc)
        .and_return(ordered_relation)
      allow(ordered_relation).to receive(:limit).with(1).and_return([matching])

      entries = described_class.new(
        relation: relation,
        threshold: 1,
        lookback_limit: 1
      ).call

      expect(ordered_relation).to have_received(:limit).with(1)
      expect(entries.map(&:subject_preview)).to eq(["Document delivery"])
    end

    it "uses squished previews instead of returning full raw text" do
      create_delivery_log(
        status: :failed,
        to_addresses: "first@example.com, second@example.com",
        subject: "first line\nsecond line with a long token",
        error_message: "error line\nsecond line with another long token",
        created_at: 1.hour.ago
      )

      entry = described_class.new(threshold: 1, preview_max_length: 24, error_message_max_length: 24).call.first

      expect(entry.recipient_preview.length).to be <= 24
      expect(entry.subject_preview).not_to include("\n")
      expect(entry.subject_preview.length).to be <= 24
      expect(entry.latest_error_message).not_to include("\n")
      expect(entry.latest_error_message.length).to be <= 24
      expect(entry.subject_preview).to end_with("...")
      expect(entry.latest_error_message).to end_with("...")
    end
  end

  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:) }
  let(:sender) { create(:user, :internal) }

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
