class Document < ApplicationRecord
  include PublicIdentifiable
  include DocumentAccess

  public_id_prefix "doc"

  belongs_to :project
  belongs_to :latest_version, class_name: "DocumentVersion", optional: true

  has_many :document_versions, dependent: :destroy
  has_many :document_permissions, dependent: :destroy
  has_many :document_taggings, dependent: :destroy
  has_many :document_tags, through: :document_taggings
  has_many :document_keywords, dependent: :destroy
  has_many :document_bookmarks, dependent: :destroy
  has_many :bookmarked_users, through: :document_bookmarks, source: :user
  has_many :read_confirmations, dependent: :destroy
  has_many :confirmed_read_users, through: :read_confirmations, source: :user
  has_many :document_review_comments, dependent: :destroy
  has_many :document_set_items, dependent: :destroy
  has_many :document_sets, through: :document_set_items
  has_many :document_catalog_items, dependent: :destroy
  has_many :document_catalogs, through: :document_catalog_items
  has_many :source_document_relations,
    class_name: "DocumentRelation",
    foreign_key: :source_document_id,
    dependent: :destroy,
    inverse_of: :source_document
  has_many :target_document_relations,
    class_name: "DocumentRelation",
    foreign_key: :target_document_id,
    dependent: :destroy,
    inverse_of: :target_document
  has_many :related_documents,
    through: :source_document_relations,
    source: :target_document

  enum :category, {
    spec: 0,
    manual: 1,
    meeting_note: 2,
    contract: 3,
    other: 9
  }

  enum :document_kind, {
    markdown: 0,
    pdf: 1,
    excel: 2,
    word: 3,
    mixed: 4
  }

  enum :visibility_policy, {
    internal_only: 0,
    restricted_external: 1,
    public_with_login: 2
  }

  enum :importance_level, {
    critical: 0,
    important: 1,
    normal: 2,
    reference: 3,
    deprecated: 4
  }

  validates :title, :slug, presence: true
  validates :slug, uniqueness: { scope: :project_id }
  validates :recommended_sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :recommended_first, -> { order(:importance_level, :recommended_sort_order, :title, :id) }
  scope :important_first, -> { where(importance_level: importance_levels.values_at(:critical, :important)).recommended_first }
end
