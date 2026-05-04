class AccessRequest < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "arq"

  belongs_to :requester, class_name: "User"
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :project, optional: true
  belongs_to :document, optional: true

  enum :requested_access_level, {
    view: 0,
    download: 1,
    manage: 2
  }

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
    cancelled: 3
  }

  validates :reason, presence: true
  validate :request_target_is_project_or_document
  validate :document_belongs_to_project_when_both_are_set
  validate :approver_must_be_internal
  validate :status_metadata_consistency

  scope :active, -> { where(status: :pending) }

  def to_param
    public_id
  end

  private

  def request_target_is_project_or_document
    return if project.present? ^ document.present?

    errors.add(:base, "request target must be either project or document")
  end

  def document_belongs_to_project_when_both_are_set
    return if project.blank? || document.blank? || document.project_id == project_id

    errors.add(:document, "must belong to project")
  end

  def approver_must_be_internal
    return if approver.blank? || approver.internal?

    errors.add(:approver, "must be internal")
  end

  def status_metadata_consistency
    case status
    when "approved"
      errors.add(:approver, "must be present") if approver.blank?
      errors.add(:approved_at, "must be present") if approved_at.blank?
      errors.add(:rejected_at, "must be blank") if rejected_at.present?
      errors.add(:rejection_reason, "must be blank") if rejection_reason.present?
    when "rejected"
      errors.add(:approver, "must be present") if approver.blank?
      errors.add(:rejected_at, "must be present") if rejected_at.blank?
      errors.add(:rejection_reason, "must be present") if rejection_reason.blank?
      errors.add(:approved_at, "must be blank") if approved_at.present?
    else
      errors.add(:approved_at, "must be blank") if approved_at.present?
      errors.add(:rejected_at, "must be blank") if rejected_at.present?
      errors.add(:rejection_reason, "must be blank") if rejection_reason.present?
    end
  end
end
