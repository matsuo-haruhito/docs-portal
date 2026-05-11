class ExternalFolderSyncRun < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efr"

  belongs_to :external_folder_sync_source

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3,
    partial: 4
  }

  enum :mode, {
    dry_run: 0,
    apply: 1
  }

  validates :status, :mode, presence: true

  def to_param
    public_id
  end

  def finish!(status:, error_message: nil, result: nil, summary: nil)
    assign_attributes(
      status:,
      error_message:,
      finished_at: Time.current
    )
    self.result_json = result if result
    self.summary_json = summary if summary
    save!
  end
end
