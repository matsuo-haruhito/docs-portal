class AccessRequest < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "areq"

  SUPPORTED_REQUESTABLE_TYPES = %w[Project Document DocumentFile].freeze

  belongs_to :requester, class_name: "User"
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :requestable, polymorphic: true

  enum :requested_access_level, { view: 0, download: 1, manage: 2 }
  enum :status, { pending: 0, approved: 1, rejected: 2, cancelled: 3 }

  validates :reason, presence: true
  validates :rejection_reason, presence: true, if: :rejected?
  validate :requester_must_be_active
  validate :requestable_type_must_be_supported
  validate :approver_must_be_internal
  validate :status_metadata_consistency

  scope :open, -> { pending }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def to_param
    public_id
  end

  def terminal?
    approved? || rejected? || cancelled?
  end

  private

  def requester_must_be_active
    errors.add(:requester, "must be active") unless requester&.active?
  end

  def requestable_type_must_be_supported
    return if SUPPORTED_REQUESTABLE_TYPES.include?(requestable_type)

    errors.add(:requestable_type, "is not supported")
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
      errors.add(:approved_at, "must be blank") if approved_at.present?
    when "cancelled"
      errors.add(:cancelled_at, "must be present") if cancelled_at.blank?
      errors.add(:approved_at, "must be blank") if approved_at.present?
      errors.add(:rejected_at, "must be blank") if rejected_at.present?
    else
      errors.add(:approved_at, "must be blank") if approved_at.present?
      errors.add(:rejected_at, "must be blank") if rejected_at.present?
      errors.add(:cancelled_at, "must be blank") if cancelled_at.present?
      errors.add(:rejection_reason, "must be blank") if rejection_reason.present?
    end
  end
end
