class WebhookDelivery < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "whdel"

  AUTO_RETRY_MAX = 3
  AUTO_RETRYABLE_STATUS_RANGE = (500..599).freeze
  AUTO_RETRY_CLAIM_STALE_AFTER = 5.minutes
  AUTO_RETRY_RECOVERY_LIMIT = 100
  AUTO_RETRY_COMPLETION_STATUSES = %w[succeeded failed].freeze

  belongs_to :webhook_endpoint
  belongs_to :notification_event

  enum :status, {
    pending: 0,
    succeeded: 1,
    failed: 2,
    retrying: 3
  }

  validates :event_type, :target_url, :request_body, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :auto_retryable, -> {
    failed
      .where("retry_count < ?", AUTO_RETRY_MAX)
      .where("response_status >= 500 OR response_status IS NULL")
      .joins(:webhook_endpoint).merge(WebhookEndpoint.where(active: true))
  }

  class << self
    def recover_stale_auto_retry_claims!(at: Time.current, limit: AUTO_RETRY_RECOVERY_LIMIT)
      ids = retrying
        .where(retry_claimed_at: ..(at - AUTO_RETRY_CLAIM_STALE_AFTER))
        .order(:retry_claimed_at, :id)
        .limit(limit)
        .pluck(:id)

      where(id: ids, status: :retrying)
        .where(retry_claimed_at: ..(at - AUTO_RETRY_CLAIM_STALE_AFTER))
        .update_all(
          status: statuses[:failed],
          retry_claim_token: nil,
          retry_claimed_at: nil,
          updated_at: at
        )
    end
  end

  def retryable?
    failed? && webhook_endpoint.active?
  end

  def auto_retryable?
    failed? &&
      webhook_endpoint.active? &&
      retry_count < AUTO_RETRY_MAX &&
      (response_status.nil? || AUTO_RETRYABLE_STATUS_RANGE.cover?(response_status))
  end

  def claim_auto_retry!(at: Time.current)
    claim_token = SecureRandom.uuid
    claimed = false

    with_lock do
      next unless auto_retryable?

      update!(
        status: :retrying,
        retry_claim_token: claim_token,
        retry_claimed_at: at
      )
      claimed = true
    end

    claimed ? claim_token : nil
  end

  def complete_auto_retry!(claim_token:, status:, response_status:, response_body:, error_message:, at: Time.current)
    normalized_status = status.to_s
    unless AUTO_RETRY_COMPLETION_STATUSES.include?(normalized_status)
      raise ArgumentError, "自動再送の完了状態が不正です。"
    end

    completed = false
    with_lock do
      next unless retrying?
      next unless retry_claim_token == claim_token

      update!(
        status: normalized_status,
        response_status:,
        response_body:,
        error_message:,
        sent_at: at,
        retry_count: retry_count + 1,
        retry_claim_token: nil,
        retry_claimed_at: nil
      )
      completed = true
    end

    completed
  end
end
