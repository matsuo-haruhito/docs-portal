class DocumentSet < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "dset"

  belongs_to :project
  belongs_to :created_by, class_name: "User", optional: true

  has_many :document_set_items, dependent: :destroy
  has_many :documents, through: :document_set_items
  has_many :document_delivery_logs, dependent: :destroy

  enum :set_type, {
    delivery: 0,
    requirement: 1,
    design: 2,
    operation: 3,
    customer_share: 4,
    internal: 5,
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
    document_set_items
      .includes(document: [:project, :latest_version], document_version: [])
      .ordered
      .select { _1.viewable_by?(user) }
  end
end
