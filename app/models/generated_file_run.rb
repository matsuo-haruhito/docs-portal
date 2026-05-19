class GeneratedFileRun < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "gfr"

  enum :status, {
    running: 0,
    completed: 1,
    failed: 2,
    skipped: 3
  }

  validates :job_id, :source_paths, :changed_files, :generated_paths, :metadata, presence: true

  def finish!(status:, generated_paths: [], error_message: nil)
    update!(
      status: status,
      generated_paths: generated_paths,
      error_message: error_message,
      finished_at: Time.current
    )
  end
end
