class NotificationReceipt < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "nrcp"

  belongs_to :notification_event
  belongs_to :user

  validates :user_id, uniqueness: { scope: :notification_event_id }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }

  def read?
    read_at.present?
  end

  def mark_as_read!(time: Time.current)
    update!(read_at: time)
  end
end
