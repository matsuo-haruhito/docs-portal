class RecurringJobRun < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "rjr"

  belongs_to :recurring_job_schedule

  enum :status, {
    enqueued: 0,
    running: 1,
    completed: 2,
    failed: 3,
    skipped: 4
  }

  validates :job_key, :job_class, :queue_name, :status, :scheduled_at, presence: true

  def to_param
    public_id
  end
end
