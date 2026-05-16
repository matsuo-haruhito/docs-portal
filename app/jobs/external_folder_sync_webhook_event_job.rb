class ExternalFolderSyncWebhookEventJob < ApplicationJob
  queue_as :default

  COALESCE_WINDOW = 2.minutes

  def perform(external_folder_sync_webhook_event_id)
    event = ExternalFolderSyncWebhookEvent.find(external_folder_sync_webhook_event_id)
    source = event.external_folder_sync_source

    unless source&.enabled?
      event.update!(status: :ignored, error_message: "External folder sync source is missing or disabled")
      return
    end

    if source.external_folder_sync_runs.running.exists?
      event.update!(status: :ignored, error_message: "External folder sync is already running; webhook event was coalesced")
      return
    end

    if recently_enqueued_event?(event, source)
      event.update!(status: :ignored, error_message: "A recent webhook sync job is already enqueued; webhook event was coalesced")
      return
    end

    ExternalFolderSyncJob.perform_later(source.id, source.created_by_id)
    event.update!(status: :enqueued, error_message: nil)
  rescue => e
    event&.update!(status: :failed, error_message: e.message)
    raise
  end

  private

  def recently_enqueued_event?(event, source)
    source.external_folder_sync_webhook_events
      .where(status: :enqueued)
      .where.not(id: event.id)
      .where("updated_at >= ?", COALESCE_WINDOW.ago)
      .exists?
  end
end
