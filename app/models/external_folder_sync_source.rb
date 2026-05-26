class ExternalFolderSyncSource < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efs"

  belongs_to :project
  belongs_to :created_by, class_name: "User"

  has_many :external_folder_sync_runs, dependent: :destroy
  has_many :external_folder_sync_items, dependent: :destroy
  has_many :external_folder_sync_subscriptions, dependent: :destroy
  has_many :external_folder_sync_webhook_events, dependent: :nullify

  encrypts :auth_config

  enum :provider, {
    google_drive: 0,
    microsoft_graph: 1
  }

  enum :auth_type, {
    service_account: 0,
    oauth_user: 1,
    microsoft_graph_connection: 2
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

  validates :name, :provider, :auth_type, :folder_url, :external_folder_id, :sync_direction, :conflict_policy, presence: true
  validates :auth_config, presence: true, if: :auth_config_required?
  validates :name, uniqueness: { scope: [:project_id, :provider] }
  validate :auth_type_must_match_provider
  validate :google_drive_folder_id_must_be_present
  validate :microsoft_graph_connection_must_be_present
  validate :mvp_scope_must_be_read_only_google_drive

  scope :enabled_only, -> { where(enabled: true) }

  def to_param
    public_id
  end

  def latest_run
    external_folder_sync_runs.order(started_at: :desc, id: :desc).first
  end

  def oauth_connected?
    oauth_user? && auth_config_json["refresh_token"].present?
  end

  def auth_config_json
    JSON.parse(auth_config.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def merge_auth_config!(attributes)
    merged = auth_config_json.merge(attributes.stringify_keys.compact_blank)
    update!(auth_config: merged.to_json)
  end

  def microsoft_graph_connection
    return unless project_id.present?

    MicrosoftGraphConnection.enabled_only.find_by(project_id: project_id)
  end

  private

  def auth_config_required?
    service_account? || oauth_connected?
  end

  def auth_type_must_match_provider
    return if provider.blank? || auth_type.blank?

    if google_drive? && microsoft_graph_connection?
      errors.add(:auth_type, "は Google Drive 用の接続方式を選択してください。")
    elsif microsoft_graph? && !microsoft_graph_connection?
      errors.add(:auth_type, "は Microsoft Graph接続 を選択してください。")
    end
  end

  def google_drive_folder_id_must_be_present
    return unless google_drive?
    return if external_folder_id.present?

    errors.add(:folder_url, "must include a Google Drive folder ID")
  end

  def microsoft_graph_connection_must_be_present
    return unless microsoft_graph?
    return if microsoft_graph_connection.present?

    errors.add(:project_id, "に有効な Microsoft Graph接続 が必要です。")
  end

  def mvp_scope_must_be_read_only_google_drive
    return unless google_drive?

    errors.add(:sync_direction, "must be external_to_portal for Google Drive MVP") unless external_to_portal?
    errors.add(:conflict_policy, "must be manual for Google Drive MVP") unless manual?
  end
end
