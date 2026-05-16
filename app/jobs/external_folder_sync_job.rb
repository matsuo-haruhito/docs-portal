class ExternalFolderSyncJob < ApplicationJob
  queue_as :default

  def perform(external_folder_sync_source_id, actor_id = nil, webhook_event_id = nil)
    source = ExternalFolderSyncSource.find(external_folder_sync_source_id)
    actor = actor_id.present? ? User.find(actor_id) : source.created_by
    webhook_event = ExternalFolderSyncWebhookEvent.find_by(id: webhook_event_id) if webhook_event_id.present?

    run = ExternalFolderSync::Runner.new(source:, mode: :apply, actor:).call
    reflect_webhook_event_result!(webhook_event, run) if webhook_event.present?
  rescue => e
    webhook_event&.update!(status: :failed, error_message: e.message)
    raise
  end

  private

  def reflect_webhook_event_result!(webhook_event, run)
    webhook_event.update!(
      status: webhook_event_status_for(run),
      error_message: webhook_event_message_for(run)
    )
  end

  def webhook_event_status_for(run)
    return :failed if run.failed? || run.partial?

    :completed
  end

  def webhook_event_message_for(run)
    return run.error_message if run.error_message.present?
    return "External folder sync was blocked by conflict warnings" if run.summary_json&.fetch("blocked_by_conflict_warnings", false)
    return "External folder sync completed with #{run.errors_count} errors" if run.errors_count.to_i.positive?

    nil
  end
end
