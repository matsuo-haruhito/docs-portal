class GitImportRun < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "gir"

  belongs_to :git_import_source, optional: true

  enum :import_mode, {
    pull: 0,
    push: 1
  }

  enum :provider, {
    github: 0
  }

  enum :status, {
    pending: 0,
    running: 1,
    imported: 2,
    skipped: 3,
    failed: 4
  }

  validates :repository_full_name, :branch, :source_path, :summary_json, presence: true

  def finish!(status:, summary: {}, error_message: nil)
    update!(
      status: status,
      summary_json: summary,
      error_message: error_message,
      finished_at: Time.current
    )
  end
end
