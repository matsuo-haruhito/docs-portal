class NotificationEventPublisher
  def initialize(actor_user: Current.user)
    @actor_user = actor_user
  end

  def publish_document_updated!(document_version:, title: nil, body: nil)
    document = document_version.document
    event = NotificationEvent.create!(
      event_type: :document_updated,
      project: document.project,
      document:,
      document_version:,
      actor_user:,
      title: title.presence || "#{document.title} が更新されました",
      body:,
      occurred_at: Time.current
    )

    create_receipts!(event, recipients_for(document))
    event
  end

  private

  attr_reader :actor_user

  def recipients_for(document)
    internal_ids = User.active_only.where(user_type: User.user_types[:internal]).pluck(:id)
    project_member_ids = ProjectMembership.where(project_id: document.project_id).pluck(:user_id)

    User.active_only
      .where(id: (internal_ids + project_member_ids).uniq)
      .select { document.viewable_by?(_1) }
  end

  def create_receipts!(event, users)
    users.each do |user|
      event.notification_receipts.find_or_create_by!(user:)
    end
  end
end
