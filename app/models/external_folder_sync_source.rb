class ExternalFolderSyncSource < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efs"

  belongs_to :project
  belongs_to :created_by, class_name: "User"

  has_many :external_folder_sync_runs, dependent: :destroy
  has_many :external_folder_sync_items, dependent: :destroy

  encrypts :auth_config

  enum :provider, {
    google_drive: 0
  }

  enum :sync_direction, {
    external_to_portal: 0,
    portal_to_external: 1,
    bidirectional: 2
  }

  enum :conflict_policy, {
    manual: 0,
    external_wins: 1,
    portal_wins: 2
  }

  validates :name, :provider, :folder_url, :external_folder_id, :sync_direction, :conflict_policy, :auth_config, presence: true
  validates :name, uniqueness: { scope: [:project_id, :provider] }
  validate :google_drive_folder_id_must_be_present

  scope :enabled_only, -> { where(enabled: true) }

  def to_param
    public_id
  end

  def latest_run
    external_folder_sync_runs.order(started_at: :desc, id: :desc).first
  end

  private

  def google_drive_folder_id_must_be_present
    return unless google_drive?
    return if external_folder_id.present?

    errors.add(:folder_url, "must include a Google Drive folder ID")
  end
end
