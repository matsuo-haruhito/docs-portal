class WebhookDelivery < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "whdel"

  AUTO_RETRY_MAX = 3
  AUTO_RETRYABLE_STATUS_RANGE = (500..599).freeze

  belongs_to :webhook_endpoint
  belongs_to :notification_event

  enum :status, {
    pending: 0,
    succeeded: 1,
    failed: 2
  }

  validates :event_type, :target_url, :request_body, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :auto_retryable, -> {
    failed
      .where("retry_count < ?", AUTO_RETRY_MAX)
      .where("response_status >= 500 OR response_status IS NULL")
      .joins(:webhook_endpoint).merge(WebhookEndpoint.where(active: true))
  }

  def retryable?
    failed? && webhook_endpoint.active?
  end

  def auto_retryable?
    failed? &&
      webhook_endpoint.active? &&
      retry_count < AUTO_RETRY_MAX &&
      (response_status.nil? || AUTO_RETRYABLE_STATUS_RANGE.cover?(response_status))
  end

  def increment_retry_count!
    increment!(:retry_count)
  end
end
