class NotificationEvent < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "nevt"

  belongs_to :project, optional: true
  belongs_to :document, optional: true
  belongs_to :document_version, optional: true
  belongs_to :actor_user, class_name: "User", optional: true

  has_many :notification_receipts, dependent: :destroy
  has_many :users, through: :notification_receipts
  has_many :webhook_deliveries, dependent: :destroy

  enum :event_type, {
    document_updated: 0,
    document_published: 1,
    important_notice: 2,
    import_completed: 3,
    import_failed: 4,
    review_approved: 5,
    qa_posted: 6,
    qa_answered: 7
  }

  validates :title, :occurred_at, presence: true

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }
end
