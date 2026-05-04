class DocumentCatalog < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "dcat"

  belongs_to :project

  has_many :document_catalog_items, dependent: :destroy
  has_many :documents, through: :document_catalog_items

  enum :audience_type, {
    customer: 0,
    internal: 1,
    developer: 2,
    delivery: 3,
    operations: 4,
    other: 9
  }

  enum :visibility_policy, {
    internal_only: 0,
    restricted_external: 1,
    public_with_login: 2
  }

  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :ordered, -> { order(:sort_order, :name, :id) }

  def to_param
    public_id
  end

  def viewable_by?(user)
    return false unless user&.active?
    return true if user.internal?
    return false if internal_only?

    project.viewable_by?(user)
  end

  def visible_items_for(user)
    document_catalog_items.includes(document: [:project, :latest_version]).ordered.select { _1.viewable_by?(user) }
  end
end
