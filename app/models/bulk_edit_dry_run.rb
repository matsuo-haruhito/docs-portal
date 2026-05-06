class BulkEditDryRun < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "bdry"

  belongs_to :project, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :confirmed_by, class_name: "User", optional: true

  enum :operation_type, {
    document_metadata: 0
  }, scopes: false

  enum :status, {
    analyzed: 0,
    confirmed: 1,
    expired: 2,
    failed: 3
  }

  validates :target_document_ids, :params_json, :summary_json, :result_json, presence: true
  validate :json_collections_must_be_present

  def document_ids
    Array(target_document_ids).map(&:to_i).uniq
  end

  private

  def json_collections_must_be_present
    errors.add(:warnings_json, "can't be nil") if warnings_json.nil?
    errors.add(:errors_json, "can't be nil") if errors_json.nil?
  end
end
