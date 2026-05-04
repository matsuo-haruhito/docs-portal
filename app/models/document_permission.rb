class DocumentPermission < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "perm"

  belongs_to :document
  belongs_to :company, optional: true
  belongs_to :user, optional: true

  enum :access_level, { view: 0, download: 1 }

  validate :exactly_one_owner_scope
  validates :document_id, uniqueness: { scope: :company_id, if: -> { company_id.present? && user_id.blank? } }
  validates :document_id, uniqueness: { scope: :user_id, if: -> { user_id.present? && company_id.blank? } }

  after_commit :broadcast_document_tree_refresh_later

  private

  def exactly_one_owner_scope
    if company_id.blank? && user_id.blank?
      errors.add(:base, "company_id or user_id is required")
    elsif company_id.present? && user_id.present?
      errors.add(:base, "company_id and user_id cannot both be set")
    end
  end
end
