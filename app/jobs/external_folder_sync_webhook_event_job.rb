class ExternalFolderSyncWebhookEventJob < ApplicationJob
  queue_as :default

  COALESCE_LIMIT = 100
  COALESCE_WINDOW = 2.minutes

  def perform(external_folder_sync_webhook_event_id)
    return if read_only_maintenance?

    event = ExternalFolderSyncWebhookEvent.find(external_folder_sync_webhook_event_id)
    return unless event.received?

    source = event.external_folder_sync_source
    unless source&.enabled?
      event.update!(status: :ignored, error_message: ExternalFolderSyncWebhookEvent::SOURCE_UNAVAILABLE_ERROR_MESSAGE)
      return
    end

    unless JobReliability::RolloutGate.enabled?
      enqueue_legacy(event, source)
      return
    end

    run, reserved_event_ids = reserve_source_events(event, source)
    return unless run

    representative = ExternalFolderSyncWebhookEvent.find(reserved_event_ids.first)
    job = ExternalFolderSyncJob.perform_later(source.id, source.created_by_id, representative.id, run.id)
    raise "External folder sync job could not be enqueued" unless job
  rescue StandardError => e
    if run
      ExternalFolderSync::RunLease.fail!(run, error: e, restore_webhook_events: true)
    elsif event && reserved_event_ids.blank?
      event.update!(status: :failed, error_message: e.message)
    end
    raise
  end

  private

  def enqueue_legacy(event, source)
    if source.external_folder_sync_runs.running.exists?
      event.update!(status: :ignored, error_message: ExternalFolderSyncWebhookEvent::RUNNING_COALESCED_ERROR_MESSAGE)
      return
    end

    if recently_enqueued_event?(event, source)
      event.update!(status: :ignored, error_message: ExternalFolderSyncWebhookEvent::RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE)
      return
    end

    job = ExternalFolderSyncJob.perform_later(source.id, source.created_by_id, event.id)
    raise "External folder sync job could not be enqueued" unless job

    event.update!(status: :enqueued, error_message: nil)
  end

  def recently_enqueued_event?(event, source)
    source.external_folder_sync_webhook_events
      .where(status: :enqueued)
      .where.not(id: event.id)
      .where("updated_at >= ?", COALESCE_WINDOW.ago)
      .exists?
  end

  def reserve_source_events(event, source)
    reserved_event_ids = []
    run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply, recover_stale: true) do |reserved_run|
      event.reload
      next false unless event.received?

      pending_events = source.external_folder_sync_webhook_events
        .received
        .order(:received_at, :id)
        .limit(COALESCE_LIMIT)
        .lock
        .to_a
      next false if pending_events.empty?

      representative = pending_events.first
      reserved_event_ids = pending_events.map(&:id)
      representative.update!(
        external_folder_sync_run: reserved_run,
        status: :enqueued,
        error_message: nil,
        payload_json: representative.payload_json.to_h.merge("coalesced_webhook_event_ids" => reserved_event_ids)
      )
      pending_events.drop(1).each do |pending_event|
        pending_event.update!(
          external_folder_sync_run: reserved_run,
          status: :enqueued,
          error_message: ExternalFolderSyncWebhookEvent::COALESCED_INTO_EVENT_ERROR_MESSAGE
        )
      end
      true
    end

    record_active_reservation_wait!(event, source) unless run
    [run, reserved_event_ids]
  end

  def record_active_reservation_wait!(event, source)
    event.reload
    source.reload
    return unless event.received?

    active_run = source.active_sync_run
    return unless active_run&.pending? || active_run&.running?

    message = if active_run.running?
      ExternalFolderSyncWebhookEvent::RUNNING_COALESCED_ERROR_MESSAGE
    else
      ExternalFolderSyncWebhookEvent::RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE
    end
    event.update!(error_message: message)
  end
end
