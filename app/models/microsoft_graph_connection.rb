class MicrosoftGraphConnection < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "mgc"

  belongs_to :project
  belongs_to :created_by, class_name: "User"

  encrypts :client_secret

  enum :auth_type, {
    client_credentials: 0
  }

  validates :name, :auth_type, :tenant_id, :client_id, :client_secret, :drive_id, :preview_folder_path, presence: true
  validates :name, uniqueness: { scope: :project_id }
  validate :preview_folder_path_must_be_safe
  validate :enabled_connection_must_be_unique_within_project

  scope :enabled_only, -> { where(enabled: true) }

  def self.preview_selected_ids_by_project(project_ids = nil)
    scope = enabled_only
    scope = scope.where(project_id: project_ids) if project_ids.present?
    scope.group(:project_id).minimum(:id)
  end

  def preview_selected?
    return false unless enabled?

    self.class.preview_selected_ids_by_project([project_id])[project_id] == id
  end

  def to_param
    public_id
  end

  def normalized_preview_folder_path
    Pathname.new(preview_folder_path.to_s).cleanpath.to_s.delete_prefix("./")
  end

  private

  def preview_folder_path_must_be_safe
    value = preview_folder_path.to_s
    normalized = Pathname.new(value.presence || ".").cleanpath.to_s
    if value.blank? || value.start_with?("/") || normalized == "." || normalized == ".." || normalized.start_with?("../")
      errors.add(:preview_folder_path, "must be a relative path")
    end
  end

  def enabled_connection_must_be_unique_within_project
    return unless enabled? && project_id.present?
    return unless self.class.enabled_only.where(project_id: project_id).where.not(id: id).exists?

    errors.add(:enabled, "は同一案件で1件だけ有効にできます。切り替える場合は現在の有効接続を先に無効化してください。")
  end
end