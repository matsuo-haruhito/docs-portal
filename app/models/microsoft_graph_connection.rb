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

  scope :enabled_only, -> { where(enabled: true) }

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
end
