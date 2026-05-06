class DocumentReviewComment < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "drc"

  belongs_to :document
  belongs_to :document_version, optional: true
  belongs_to :parent, class_name: "DocumentReviewComment", optional: true
  belongs_to :author, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true

  has_many :replies, class_name: "DocumentReviewComment", foreign_key: :parent_id, dependent: :nullify

  enum :comment_type, {
    note: 0,
    issue: 1,
    request_change: 2,
    question: 3
  }

  enum :status, {
    open: 0,
    resolved: 1,
    rejected: 2
  }

  validates :body, presence: true
  validates :internal_only, inclusion: { in: [true, false] }
  validates :text_line_start, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validates :text_line_end, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validate :author_must_be_internal
  validate :document_version_belongs_to_document
  validate :parent_belongs_to_same_document
  validate :parent_visibility_matches
  validate :text_line_range_is_valid
  validate :resolved_fields_consistency

  scope :visible_to, ->(user) { user&.internal? ? all : where(internal_only: false) }
  scope :unresolved, -> { where(status: statuses.values_at(:open, :rejected)) }
  scope :roots, -> { where(parent_id: nil) }

  def to_param
    public_id
  end

  def resolve!(user)
    update!(status: :resolved, resolved_by: user, resolved_at: Time.current)
  end

  def location_label
    parts = []
    parts << "lines #{text_line_start}-#{text_line_end || text_line_start}" if text_line_start.present?
    parts << text_anchor_path if text_anchor_path.present?
    parts << source_path if source_path.present?
    parts.join(" / ").presence
  end

  def public_thread?
    !internal_only?
  end

  def qa_status_label
    return "回答済み" if resolved?
    return "クローズ" if rejected?

    "受付中"
  end

  private

  def author_must_be_internal
    return if public_thread?
    return if author&.internal?

    errors.add(:author, "must be internal")
  end

  def document_version_belongs_to_document
    return if document_version.blank? || document_version.document_id == document_id

    errors.add(:document_version, "must belong to document")
  end

  def parent_belongs_to_same_document
    return if parent.blank? || parent.document_id == document_id

    errors.add(:parent, "must belong to the same document")
  end

  def parent_visibility_matches
    return if parent.blank? || parent.internal_only == internal_only

    errors.add(:internal_only, "must match parent visibility")
  end

  def text_line_range_is_valid
    return if text_line_start.blank? || text_line_end.blank?
    return if text_line_end >= text_line_start

    errors.add(:text_line_end, "must be greater than or equal to text_line_start")
  end

  def resolved_fields_consistency
    if resolved?
      errors.add(:resolved_by, "must be present") if resolved_by.blank?
      errors.add(:resolved_at, "must be present") if resolved_at.blank?
    elsif resolved_by.present? || resolved_at.present?
      errors.add(:status, "must be resolved when resolved fields are present")
    end
  end
end
