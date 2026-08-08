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

  STALE_ENQUEUED_ERROR_MESSAGE = "Runnerが期限内に開始されなかったため回収しました"

  scope :active, -> { where(status: statuses.values_at(:enqueued, :running)) }
  scope :stale_enqueued, ->(at = Time.current) {
    enqueued.where("enqueued_at IS NULL OR enqueued_at <= ?", at - RecurringJobSchedule::STALE_LOCK_AFTER)
  }

  validates :job_key, :job_class, :queue_name, :status, :scheduled_at, presence: true

  def to_param
    public_id
  end
end
