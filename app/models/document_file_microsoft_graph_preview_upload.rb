class DocumentFileMicrosoftGraphPreviewUpload < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "mgpv"

  belongs_to :document_file
  belongs_to :microsoft_graph_connection

  scope :active, -> { where(deleted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired_or_deleted_pending, -> { where(deleted_at: nil).where("expires_at <= ?", Time.current) }

  validates :fingerprint, :drive_id, :drive_item_id, :drive_item_path, :uploaded_at, :expires_at, presence: true

  def to_param
    public_id
  end

  def active?
    deleted_at.blank? && expires_at.future?
  end
end
