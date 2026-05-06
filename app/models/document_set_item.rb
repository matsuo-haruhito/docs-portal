class DocumentSetItem < ApplicationRecord
  belongs_to :document_set
  belongs_to :document
  belongs_to :document_version, optional: true

  validates :document_id, uniqueness: { scope: :document_set_id }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :document_belongs_to_document_set_project
  validate :document_version_belongs_to_document

  scope :ordered, -> { order(:sort_order, :id) }

  def effective_document_version
    document_version || document.latest_version
  end

  def viewable_by?(user)
    return false unless document_set.viewable_by?(user) && document.viewable_by?(user)

    version = effective_document_version
    version.present? && version.viewable_by?(user)
  end

  private

  def document_belongs_to_document_set_project
    return if document.blank? || document_set.blank? || document.project_id == document_set.project_id

    errors.add(:document, "must belong to document set project")
  end

  def document_version_belongs_to_document
    return if document_version.blank? || document.blank? || document_version.document_id == document_id

    errors.add(:document_version, "must belong to document")
  end
end
