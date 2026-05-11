class DocumentFileGoogleDrivePreviewUpload < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "gdpv"

  belongs_to :document_file

  scope :active, -> { where(deleted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired_or_deleted_pending, -> { where(deleted_at: nil).where("expires_at <= ?", Time.current) }

  validates :fingerprint, :drive_file_id, :uploaded_at, :expires_at, presence: true

  def to_param
    public_id
  end

  def active?
    deleted_at.blank? && expires_at.future?
  end
end
