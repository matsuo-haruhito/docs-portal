class ExternalFolderSyncSubscription < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efsub"

  belongs_to :external_folder_sync_source
  has_many :external_folder_sync_webhook_events, dependent: :nullify

  enum :provider, {
    google_drive: 0,
    sharepoint: 1
  }

  enum :status, {
    pending: 0,
    active: 1,
    expired: 2,
    failed: 3,
    disabled: 4
  }

  validates :provider, :status, presence: true

  def to_param
    public_id
  end
end
