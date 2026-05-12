class RecurringJobSchedule < ApplicationRecord
  include PublicIdentifiable

  DEFAULT_INTERVAL_SECONDS = 24.hours.to_i
  STALE_LOCK_AFTER = 10.minutes

  public_id_prefix "rjs"

  has_many :recurring_job_runs, dependent: :destroy

  validates :job_key, :job_class, :queue_name, :interval_seconds, :next_run_at, presence: true
  validates :job_key, uniqueness: true
  validates :interval_seconds, numericality: { greater_than: 0, only_integer: true }

  scope :enabled_only, -> { where(enabled: true) }
  scope :due, -> { enabled_only.where("next_run_at <= ? OR run_requested_at IS NOT NULL", Time.current) }
  scope :locked_stale, -> { where.not(locked_at: nil).where("locked_at < ?", STALE_LOCK_AFTER.ago) }

  def to_param
    public_id
  end

  def due?
    enabled? && (run_requested_at.present? || next_run_at <= Time.current)
  end

  def running_run?
    recurring_job_runs.where(status: RecurringJobRun.statuses[:running]).exists?
  end

  def next_run_after(from_time = Time.current)
    from_time + interval_seconds.seconds
  end
end
