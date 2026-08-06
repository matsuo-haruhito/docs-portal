# frozen_string_literal: true

class WebhookDeliveryAutoRetryJob < ApplicationJob
  queue_as :default

  def perform
    WebhookDelivery.auto_retryable.find_each do |delivery|
      retry_delivery(delivery)
    end
  end

  private

  def retry_delivery(delivery)
    delivery.increment_retry_count!
    WebhookDeliveryDispatcher.new(delivery).dispatch!
  rescue => e
    Rails.logger.warn("WebhookDeliveryAutoRetryJob: retry failed for #{delivery.public_id}: #{e.class}: #{e.message}")
  end
end
