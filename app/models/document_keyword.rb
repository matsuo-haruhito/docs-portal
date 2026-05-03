class DocumentKeyword < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "dkey"

  belongs_to :document

  before_validation :normalize_keyword

  validates :keyword, presence: true
  validates :normalized_keyword, presence: true, uniqueness: { scope: :document_id }

  scope :ordered, -> { order(:sort_order, :normalized_keyword) }

  def self.normalize(value)
    value.to_s.strip.downcase.unicode_normalize(:nfkc)
  end

  private

  def normalize_keyword
    self.keyword = keyword.to_s.strip
    self.normalized_keyword = self.class.normalize(keyword)
  end
end
