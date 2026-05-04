class DocumentCatalogItem < ApplicationRecord
  belongs_to :document_catalog
  belongs_to :document

  validates :document_id, uniqueness: { scope: :document_catalog_id }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :document_belongs_to_catalog_project

  scope :ordered, -> { order(:sort_order, :id) }

  def viewable_by?(user)
    document_catalog.viewable_by?(user) && document.viewable_by?(user)
  end

  private

  def document_belongs_to_catalog_project
    return if document.blank? || document_catalog.blank? || document.project_id == document_catalog.project_id

    errors.add(:document, "must belong to document catalog project")
  end
end
