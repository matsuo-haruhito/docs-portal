class WebhookDelivery < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "whdel"

  belongs_to :webhook_endpoint
  belongs_to :notification_event

  enum :status, {
    pending: 0,
    succeeded: 1,
    failed: 2
  }

  validates :event_type, :target_url, :request_body, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
