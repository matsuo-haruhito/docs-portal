class MasterSyncReceipt < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "xrcpt"

  validates :idempotency_key, :request_digest, :source_system, :resource_type,
    :external_id, :response_status, :completed_at, presence: true
  validates :idempotency_key, uniqueness: true
  validates :request_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :resource_type, inclusion: { in: ExternalMasterSyncMapping::RESOURCE_TARGET_TYPES.keys }
  validates :response_status, inclusion: { in: 100..599 }
end
