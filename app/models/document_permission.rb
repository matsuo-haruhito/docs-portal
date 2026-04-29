class DocumentPermission < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "perm"

  belongs_to :document
  belongs_to :company, optional: true
  belongs_to :user, optional: true

  enum :access_level, { view: 0, download: 1 }

  validate :company_or_user_presence
  validates :document_id, uniqueness: { scope: %i[company_id user_id] }

  private

  def company_or_user_presence
    errors.add(:base, "company_id or user_id is required") if company_id.blank? && user_id.blank?
  end
end
