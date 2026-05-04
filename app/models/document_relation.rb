class DocumentRelation < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "drel"

  belongs_to :source_document, class_name: "Document"
  belongs_to :target_document, class_name: "Document"

  enum :relation_type, {
    related: 0,
    prerequisite: 1,
    appendix: 2,
    source: 3,
    output: 4,
    previous_version: 5
  }

  validates :source_document, :target_document, :relation_type, presence: true
  validates :target_document_id, uniqueness: { scope: %i[source_document_id relation_type] }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :different_documents

  private

  def different_documents
    return if source_document_id.blank? || target_document_id.blank?
    return if source_document_id != target_document_id

    errors.add(:target_document, "must be different from source document")
  end
end
