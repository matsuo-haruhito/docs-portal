require "rails_helper"

RSpec.describe WebhookDelivery, type: :model do
  describe "durable automatic retry claims" do
    it "claims an eligible delivery once without consuming retry budget" do
      delivery = create(:webhook_delivery, status: :failed, response_status: 503, retry_count: 1)
      stale_instance = described_class.find(delivery.id)

      claim_token = delivery.claim_auto_retry!(at: Time.zone.parse("2026-08-06 12:00:00"))

      expect(claim_token).to be_present
      expect(delivery.reload).to have_attributes(
        status: "retrying",
        retry_count: 1,
        retry_claim_token: claim_token,
        retry_claimed_at: Time.zone.parse("2026-08-06 12:00:00")
      )
      expect(stale_instance.claim_auto_retry!).to be_nil
    end

    it "lets only the current token finalize an attempt and increments the count once" do
      delivery = create(:webhook_delivery, status: :failed, response_status: 503)
      claim_token = delivery.claim_auto_retry!

      expect(delivery.complete_auto_retry!(
        claim_token: "stale-token",
        status: :succeeded,
        response_status: 200,
        response_body: "stale",
        error_message: nil,
        at: Time.current
      )).to be(false)

      expect(delivery.complete_auto_retry!(
        claim_token:,
        status: :succeeded,
        response_status: 200,
        response_body: "accepted",
        error_message: nil,
        at: Time.current
      )).to be(true)

      expect(delivery.reload).to have_attributes(
        status: "succeeded",
        retry_count: 1,
        response_status: 200,
        response_body: "accepted",
        retry_claim_token: nil,
        retry_claimed_at: nil
      )
    end

    it "recovers only stale claims without consuming retry budget" do
      stale = create(:webhook_delivery, status: :retrying, response_status: 503, retry_count: 2,
        retry_claim_token: SecureRandom.uuid, retry_claimed_at: 6.minutes.ago)
      fresh = create(:webhook_delivery, status: :retrying, response_status: 503, retry_count: 1,
        retry_claim_token: SecureRandom.uuid, retry_claimed_at: 1.minute.ago)

      expect(described_class.recover_stale_auto_retry_claims!).to eq(1)

      expect(stale.reload).to have_attributes(
        status: "failed",
        retry_count: 2,
        retry_claim_token: nil,
        retry_claimed_at: nil
      )
      expect(fresh.reload).to be_retrying
    end

    it "rejects automatic claims for permanent failures, inactive endpoints, and exhausted rows" do
      permanent = create(:webhook_delivery, status: :failed, response_status: 422)
      inactive = create(:webhook_delivery, status: :failed, response_status: 503)
      inactive.webhook_endpoint.update!(active: false)
      exhausted = create(:webhook_delivery, status: :failed, response_status: 503, retry_count: described_class::AUTO_RETRY_MAX)

      expect(permanent.claim_auto_retry!).to be_nil
      expect(inactive.claim_auto_retry!).to be_nil
      expect(exhausted.claim_auto_retry!).to be_nil
    end
  end
end
