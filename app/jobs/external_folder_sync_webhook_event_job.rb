class ExternalFolderSyncWebhookEventJob < ApplicationJob
  queue_as :default

  def perform(external_folder_sync_webhook_event_id)
    event = ExternalFolderSyncWebhookEvent.find(external_folder_sync_webhook_event_id)
    source = event.external_folder_sync_source

    unless source&.enabled?
      event.update!(status: :ignored, error_message: "External folder sync source is missing or disabled")
      return
    end

    ExternalFolderSyncJob.perform_later(source.id, source.created_by_id)
    event.update!(status: :enqueued, error_message: nil)
  rescue => e
    event&.update!(status: :failed, error_message: e.message)
    raise
  end
end
