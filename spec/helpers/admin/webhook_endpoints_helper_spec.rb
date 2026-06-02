require "rails_helper"

RSpec.describe Admin::WebhookEndpointsHelper, type: :helper do
  describe "#webhook_endpoint_display_target_url" do
    it "keeps host and path while hiding query parameter names and values" do
      display_url = helper.webhook_endpoint_display_target_url(
        "https://hooks.example.test/docs/events?token=secret-value&signature=abc123"
      )

      expect(display_url).to eq("https://hooks.example.test/docs/events?...")
      expect(display_url).not_to include("token")
      expect(display_url).not_to include("secret-value")
      expect(display_url).not_to include("signature")
      expect(display_url).not_to include("abc123")
    end

    it "keeps non-default ports and falls back to slash for root paths" do
      expect(helper.webhook_endpoint_display_target_url("https://hooks.example.test:8443?token=secret")).to eq(
        "https://hooks.example.test:8443/?..."
      )
    end

    it "does not expose query-looking suffixes for unparseable values" do
      display_url = helper.webhook_endpoint_display_target_url("not a url?token=secret-value&signature=abc123")

      expect(display_url).to eq("not a url?...")
      expect(display_url).not_to include("secret-value")
      expect(display_url).not_to include("signature")
    end
  end
end
