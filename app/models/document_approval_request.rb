class DocumentApprovalRequest < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "dar"

  belongs_to :document
  belongs_to :requester, class_name: "User"
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :acted_by, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, cancelled: 2 }

  validates :title, presence: true
  validate :requester_must_be_active
  validate :requester_must_view_document
  validate :approver_must_be_internal
  validate :acted_by_must_be_internal_or_requester
  validate :status_metadata_consistency

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def to_param
    public_id
  end

  def approve!(actor:)
    update!(status: :approved, acted_by: actor, approved_at: Time.current, cancelled_at: nil)
  end

  def cancel!(actor:)
    update!(status: :cancelled, acted_by: actor, cancelled_at: Time.current, approved_at: nil)
  end

  private

  def requester_must_be_active
    errors.add(:requester, "must be active") unless requester&.active?
  end

  def requester_must_view_document
    return if requester.blank? || document.blank?
    return if document.viewable_by?(requester)

    errors.add(:requester, "must be able to view the document")
  end

  def approver_must_be_internal
    return if approver.blank? || approver.internal?

    errors.add(:approver, "must be internal")
  end

  def acted_by_must_be_internal_or_requester
    return if acted_by.blank? || acted_by.internal? || acted_by == requester

    errors.add(:acted_by, "must be internal or requester")
  end

  def status_metadata_consistency
    case status
    when "approved"
      errors.add(:acted_by, "must be present") if acted_by.blank?
      errors.add(:approved_at, "must be present") if approved_at.blank?
      errors.add(:cancelled_at, "must be blank") if cancelled_at.present?
    when "cancelled"
      errors.add(:acted_by, "must be present") if acted_by.blank?
      errors.add(:cancelled_at, "must be present") if cancelled_at.blank?
      errors.add(:approved_at, "must be blank") if approved_at.present?
    else
      errors.add(:approved_at, "must be blank") if approved_at.present?
      errors.add(:cancelled_at, "must be blank") if cancelled_at.present?
    end
  end
end
