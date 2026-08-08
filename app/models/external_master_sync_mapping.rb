class ExternalMasterSyncMapping < ApplicationRecord
  include PublicIdentifiable

  RESOURCE_TARGET_TYPES = {
    "company" => "Company",
    "project" => "Project",
    "document" => "Document"
  }.freeze

  public_id_prefix "xsync"

  belongs_to :sync_target, polymorphic: true, optional: true

  validates :source_system, :resource_type, :external_id, :source_updated_at, presence: true
  validates :resource_type, inclusion: { in: RESOURCE_TARGET_TYPES.keys }
  validates :source_system, uniqueness: { scope: %i[resource_type external_id] }
  validate :sync_target_matches_resource_type
  validate :sync_target_columns_are_both_present_or_blank

  private

  def sync_target_matches_resource_type
    return if sync_target_type.blank? || resource_type.blank?
    return if sync_target_type == RESOURCE_TARGET_TYPES[resource_type]

    errors.add(:sync_target_type, "は同期リソース種別と一致していません")
  end

  def sync_target_columns_are_both_present_or_blank
    return if sync_target_type.present? == sync_target_id.present?

    errors.add(:sync_target, "の種別とIDは両方を指定してください")
  end
end
