class ExternalFolderSyncWebhookEvent < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efevt"

  belongs_to :external_folder_sync_source, optional: true
  belongs_to :external_folder_sync_subscription, optional: true

  enum :provider, {
    google_drive: 0,
    sharepoint: 1
  }

  enum :status, {
    received: 0,
    enqueued: 1,
    ignored: 2,
    failed: 3,
    completed: 4
  }

  validates :provider, :status, :received_at, presence: true

  def to_param
    public_id
  end
end
