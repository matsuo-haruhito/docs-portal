class ExternalFolderSyncItem < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efi"

  belongs_to :external_folder_sync_source
  belongs_to :document, optional: true
  belongs_to :document_version, optional: true
  belongs_to :document_file, optional: true

  enum :sync_status, {
    synced: 0,
    external_changed: 1,
    portal_changed: 2,
    conflict: 3,
    delete_detected: 4,
    error: 5
  }

  validates :external_item_id, :path, :name, :sync_status, presence: true
  validates :external_item_id, uniqueness: { scope: :external_folder_sync_source_id }

  def to_param
    public_id
  end
end
