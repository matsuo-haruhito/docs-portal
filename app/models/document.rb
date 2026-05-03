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

  validates :title, :slug, presence: true
  validates :slug, uniqueness: { scope: :project_id }
end
