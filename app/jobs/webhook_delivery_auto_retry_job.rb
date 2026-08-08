# frozen_string_literal: true

class WebhookDeliveryAutoRetryJob < ApplicationJob
  queue_as :default

  BATCH_LIMIT = 100

  def perform
    return if read_only_maintenance?
    return unless JobReliability::RolloutGate.enabled?

    WebhookDelivery.recover_stale_auto_retry_claims!(limit: BATCH_LIMIT)
    delivery_ids = WebhookDelivery.auto_retryable
      .order(:created_at, :id)
      .limit(BATCH_LIMIT)
      .pluck(:id)
    dispatcher = WebhookDeliveryDispatcher.new

    delivery_ids.each do |delivery_id|
      delivery = WebhookDelivery.find_by(id: delivery_id)
      retry_delivery(dispatcher, delivery) if delivery
    end
  end

  private

  def retry_delivery(dispatcher, delivery)
    dispatcher.retry_in_place!(delivery)
  rescue StandardError => e
    Rails.logger.warn("WebhookDeliveryAutoRetryJob: retry failed for #{delivery.public_id}: #{e.class}: #{e.message}")
  end
end
