class DocumentTagging < ApplicationRecord
  belongs_to :document
  belongs_to :document_tag

  validates :document_tag_id, uniqueness: { scope: :document_id }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }
end
