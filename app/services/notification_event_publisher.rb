class NotificationEventPublisher
  def initialize(actor_user: Current.user, webhook_dispatcher: WebhookDeliveryDispatcher.new)
    @actor_user = actor_user
    @webhook_dispatcher = webhook_dispatcher
  end

  def publish_document_updated!(document_version:, title: nil, body: nil)
    document = document_version.document
    publish!(
      event_type: :document_updated,
      project: document.project,
      document:,
      document_version:,
      title: title.presence || "#{document.title} が更新されました",
      body:
    ) do |event|
      create_receipts!(event, recipients_for(document))
    end
  end

  def publish_document_published!(document_version:, title: nil, body: nil)
    document = document_version.document
    publish!(
      event_type: :document_published,
      project: document.project,
      document:,
      document_version:,
      title: title.presence || "#{document.title} が公開されました",
      body:
    ) do |event|
      create_receipts!(event, recipients_for(document))
    end
  end

  def publish_import_result!(project:, succeeded:, title: nil, body: nil)
    publish!(
      event_type: succeeded ? :import_completed : :import_failed,
      project:,
      title: title.presence || (succeeded ? "インポートが完了しました" : "インポートに失敗しました"),
      body:
    )
  end

  def publish_review_approved!(document:, document_version: document.latest_version, title: nil, body: nil)
    publish!(
      event_type: :review_approved,
      project: document.project,
      document:,
      document_version:,
      title: title.presence || "#{document.title} のレビューが承認されました",
      body:
    ) do |event|
      create_receipts!(event, recipients_for(document))
    end
  end

  def publish_qa_posted!(document:, document_version: document.latest_version, title: nil, body: nil)
    publish!(
      event_type: :qa_posted,
      project: document.project,
      document:,
      document_version:,
      title: title.presence || "#{document.title} にQ&Aが投稿されました",
      body:
    ) do |event|
      create_receipts!(event, recipients_for(document))
    end
  end

  def publish_qa_answered!(document:, document_version: document.latest_version, title: nil, body: nil)
    publish!(
      event_type: :qa_answered,
      project: document.project,
      document:,
      document_version:,
      title: title.presence || "#{document.title} のQ&Aに回答されました",
      body:
    ) do |event|
      create_receipts!(event, recipients_for(document))
    end
  end

  private

  attr_reader :actor_user, :webhook_dispatcher

  def publish!(event_type:, title:, body: nil, project: nil, document: nil, document_version: nil)
    event = NotificationEvent.create!(
      event_type:,
      project:,
      document:,
      document_version:,
      actor_user:,
      title:,
      body:,
      occurred_at: Time.current
    )

    yield(event) if block_given?
    webhook_dispatcher.dispatch!(event)
    event
  end

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
