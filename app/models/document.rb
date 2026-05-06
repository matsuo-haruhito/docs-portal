class Document < ApplicationRecord
  include PublicIdentifiable
  include DocumentAccess

  public_id_prefix "doc"

  belongs_to :project
  belongs_to :latest_version, class_name: "DocumentVersion", optional: true
  belongs_to :archived_by_user, class_name: "User", optional: true

  has_many :document_versions, dependent: :destroy
  has_many :document_permissions, dependent: :destroy
  has_many :document_taggings, dependent: :destroy
  has_many :document_tags, through: :document_taggings
  has_many :document_keywords, dependent: :destroy
  has_many :document_bookmarks, dependent: :destroy
  has_many :bookmarked_users, through: :document_bookmarks, source: :user
  has_many :read_confirmations, dependent: :destroy
  has_many :confirmed_read_users, through: :read_confirmations, source: :user
  has_many :document_approval_requests, dependent: :destroy
  has_many :document_review_comments, dependent: :destroy
  has_many :document_delivery_logs, dependent: :destroy
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

  after_commit :broadcast_document_tree_refresh_later

  scope :active_only, -> { where(archived_at: nil) }
  scope :archived_only, -> { where.not(archived_at: nil) }
  scope :recommended_first, -> { order(:importance_level, :recommended_sort_order, :title, :id) }
  scope :important_first, -> { where(importance_level: importance_levels.values_at(:critical, :important)).recommended_first }

  def to_param
    slug
  end

  def visible_in_portal_for?(user)
    return false if archived?
    return false unless viewable_by?(user)
    return true if user&.internal?
    return true if latest_version.blank?

    latest_version.viewable_by?(user)
  end

  def archived?
    archived_at.present?
  end

  def archive!(actor:, retention_until: nil, discard_candidate_at: nil)
    transaction do
      update!(
        archived_at: Time.current,
        archived_by_user: actor,
        retention_until: retention_until.presence || self.retention_until,
        discard_candidate_at: discard_candidate_at.presence || self.discard_candidate_at
      )
      NotificationEvent.create!(
        event_type: :important_notice,
        project:,
        document: self,
        actor_user: actor,
        title: "Document archived",
        body: "#{title} was archived",
        occurred_at: Time.current
      )
    end
  end

  def restore!(actor:)
    transaction do
      update!(archived_at: nil, archived_by_user: nil)
      NotificationEvent.create!(
        event_type: :important_notice,
        project:,
        document: self,
        actor_user: actor,
        title: "Document restored",
        body: "#{title} was restored from archive",
        occurred_at: Time.current
      )
    end
  end
end
