require "rails_helper"

RSpec.describe WebhookDeliveryAutoRetryJob, type: :job do
  class WebhookRetryProcessTermination < Exception; end

  before do
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
  end

  it "retries an eligible delivery once and records the completed attempt" do
    delivery = create(:webhook_delivery, status: :failed, response_status: 503)
    dispatcher = instance_double(WebhookDeliveryDispatcher)
    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:retry_in_place!) do |claimed_delivery|
      token = claimed_delivery.claim_auto_retry!
      claimed_delivery.complete_auto_retry!(
        claim_token: token,
        status: :succeeded,
        response_status: 200,
        response_body: "accepted",
        error_message: nil,
        at: Time.current
      )
    end

    described_class.perform_now

    expect(dispatcher).to have_received(:retry_in_place!).once.with(delivery)
    expect(delivery.reload).to have_attributes(status: "succeeded", retry_count: 1)
  end

  it "leaves a pre-send process termination claimed without consuming retry budget" do
    delivery = create(:webhook_delivery, status: :failed, response_status: 503)
    dispatcher = instance_double(WebhookDeliveryDispatcher)
    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(dispatcher).to receive(:retry_in_place!) do |claimed_delivery|
      claimed_delivery.claim_auto_retry!
      raise WebhookRetryProcessTermination, "worker stopped"
    end

    expect { described_class.perform_now }.to raise_error(WebhookRetryProcessTermination)

    expect(delivery.reload).to have_attributes(status: "retrying", retry_count: 0)
    expect(delivery.retry_claim_token).to be_present
  end

  it "recovers stale claims without consuming retry budget" do
    delivery = create(:webhook_delivery, status: :retrying, response_status: 503, retry_count: 1,
      retry_claim_token: SecureRandom.uuid, retry_claimed_at: 6.minutes.ago)
    dispatcher = instance_double(WebhookDeliveryDispatcher, retry_in_place!: nil)
    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)

    described_class.perform_now

    expect(delivery.reload).to have_attributes(
      status: "failed",
      retry_count: 1,
      retry_claim_token: nil,
      retry_claimed_at: nil
    )
  end

  it "does not claim, recover, or send while the reliability rollout gate is off" do
    eligible = create(:webhook_delivery, status: :failed, response_status: 503)
    stale = create(:webhook_delivery, status: :retrying, response_status: 503,
      retry_claim_token: SecureRandom.uuid, retry_claimed_at: 6.minutes.ago)
    original_attributes = [eligible, stale].to_h do |delivery|
      [delivery.id, delivery.attributes.slice("status", "retry_count", "retry_claim_token", "retry_claimed_at", "updated_at")]
    end
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)
    allow(WebhookDeliveryDispatcher).to receive(:new)

    described_class.perform_now

    expect(WebhookDeliveryDispatcher).not_to have_received(:new)
    [eligible, stale].each do |delivery|
      expect(delivery.reload.attributes.slice(*original_attributes.fetch(delivery.id).keys))
        .to eq(original_attributes.fetch(delivery.id))
    end
  end

  it "does not claim, recover, or send during read-only maintenance" do
    eligible = create(:webhook_delivery, status: :failed, response_status: 503)
    stale = create(:webhook_delivery, status: :retrying, response_status: 503,
      retry_claim_token: SecureRandom.uuid, retry_claimed_at: 6.minutes.ago)
    original_attributes = [eligible, stale].to_h do |delivery|
      [delivery.id, delivery.attributes.slice("status", "retry_count", "retry_claim_token", "retry_claimed_at", "updated_at")]
    end
    dispatcher = instance_double(WebhookDeliveryDispatcher, retry_in_place!: nil)
    allow(WebhookDeliveryDispatcher).to receive(:new).and_return(dispatcher)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("READ_ONLY_MAINTENANCE", nil).and_return("true")

    described_class.perform_now

    expect(dispatcher).not_to have_received(:retry_in_place!)
    [eligible, stale].each do |delivery|
      expect(delivery.reload.attributes.slice(*original_attributes.fetch(delivery.id).keys))
        .to eq(original_attributes.fetch(delivery.id))
    end
  end
end
