class DocumentReviewComment < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "drc"

  belongs_to :document
  belongs_to :document_version, optional: true
  belongs_to :author, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true

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
  validates :internal_only, inclusion: { in: [true] }
  validate :author_must_be_internal
  validate :document_version_belongs_to_document
  validate :resolved_fields_consistency

  scope :visible_to, ->(user) { user&.internal? ? all : none }
  scope :unresolved, -> { where(status: statuses.values_at(:open, :rejected)) }

  def to_param
    public_id
  end

  def resolve!(user)
    update!(status: :resolved, resolved_by: user, resolved_at: Time.current)
  end

  private

  def author_must_be_internal
    return if author&.internal?

    errors.add(:author, "must be internal")
  end

  def document_version_belongs_to_document
    return if document_version.blank? || document_version.document_id == document_id

    errors.add(:document_version, "must belong to document")
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
