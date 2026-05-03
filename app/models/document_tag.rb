class DocumentTag < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "dtag"

  has_many :document_taggings, dependent: :destroy
  has_many :documents, through: :document_taggings

  before_validation :normalize_name

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true

  scope :ordered, -> { order(:normalized_name) }

  def self.normalize(value)
    value.to_s.strip.downcase.unicode_normalize(:nfkc)
  end

  private

  def normalize_name
    self.name = name.to_s.strip
    self.normalized_name = self.class.normalize(name)
  end
end
