require "rails_helper"

RSpec.describe GeneratedFileEvent, type: :model do
  describe "validations" do
    it "requires event key, path, operation, scheduled time, and last seen time" do
      event = described_class.new

      expect(event).not_to be_valid
      expect(event.errors[:event_key]).to be_present
      expect(event.errors[:path]).to be_present
      expect(event.errors[:operation]).to be_present
      expect(event.errors[:scheduled_at]).to be_present
      expect(event.errors[:last_seen_at]).to be_present
    end
  end

  describe ".build_event_key" do
    it "normalizes relative path prefixes" do
      key = described_class.build_event_key(
        path: "./docs/../docs/source.yml",
        operation: "update",
        event_source: "manual"
      )

      expect(key).to eq("docs/source.yml:update:manual")
    end
  end

  describe ".due" do
    it "returns only pending events scheduled at or before the given time" do
      now = Time.current
      due = create(:generated_file_event, scheduled_at: now)
      future = create(:generated_file_event, scheduled_at: now + 1.minute)
      failed = create(:generated_file_event, :failed, scheduled_at: now - 1.minute)

      expect(described_class.due(now)).to contain_exactly(due)
      expect(described_class.due(now)).not_to include(future, failed)
    end
  end

  describe "state markers" do
    it "marks an event as processed" do
      event = create(:generated_file_event, :failed, error_message: "boom")

      event.mark_processed!

      expect(event).to be_processed
      expect(event.error_message).to be_nil
      expect(event.processed_at).to be_present
    end

    it "marks an event as failed" do
      event = create(:generated_file_event, :processed, error_message: nil)

      event.mark_failed!("boom")

      expect(event).to be_failed
      expect(event.error_message).to eq("boom")
      expect(event.processed_at).to be_present
    end
  end
end
