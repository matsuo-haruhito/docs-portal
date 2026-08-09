class McpMutationReceipt < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "mcpr"

  OPERATIONS = %w[apply_revision publish_revision].freeze

  belongs_to :oauth_application, class_name: "Doorkeeper::Application"
  belongs_to :user
  belongs_to :document, optional: true
  belongs_to :document_version, optional: true

  validates :operation, inclusion: { in: OPERATIONS }
  validates :idempotency_key_digest, :request_digest, :completed_at, presence: true
  validates :idempotency_key_digest, :request_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :idempotency_key_digest,
    uniqueness: { scope: %i[oauth_application_id user_id operation] }
end
