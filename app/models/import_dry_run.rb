class ImportDryRun < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "idry"

  belongs_to :project, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :confirmed_by, class_name: "User", optional: true

  enum :import_mode, {
    zip: 0,
    git_pull: 1,
    git_push: 2,
    manual_upload: 3
  }, prefix: true

  enum :status, {
    analyzed: 0,
    confirmed: 1,
    expired: 2,
    failed: 3
  }

  validates :summary_json, :result_json, :warnings_json, :errors_json, presence: true
end
