require "rails_helper"

RSpec.describe WebhookEndpoint, type: :model do
  describe ".subscribed_to" do
    it "returns only active endpoints subscribed to the event type" do
      subscribed_endpoint = create(:webhook_endpoint, active: true, event_types: %w[document_updated])
      create(:webhook_endpoint, active: false, event_types: %w[document_updated])
      create(:webhook_endpoint, active: true, event_types: %w[document_published])

      expect(described_class.subscribed_to("document_updated")).to contain_exactly(subscribed_endpoint)
    end
  end
end
