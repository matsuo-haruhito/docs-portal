class ExternalFolderSyncWebhookEventReconciliationJob < ApplicationJob
  queue_as :default

  DEFAULT_LIMIT = 100
  MAX_LIMIT = 500

  def perform(limit: DEFAULT_LIMIT)
    return if read_only_maintenance?
    return unless JobReliability::RolloutGate.enabled?

    normalized_limit = limit.to_i.clamp(1, MAX_LIMIT)
    ExternalFolderSync::RunLease.recover_stale_sources!(limit: normalized_limit)
    converge_terminal_run_events!(normalized_limit)
    recover_legacy_stale_deliveries!(normalized_limit)

    event_ids = ExternalFolderSyncWebhookEvent
      .received
      .order(:received_at, :id)
      .limit(normalized_limit)
      .pluck(:id)

    errors = event_ids.filter_map do |event_id|
      ExternalFolderSyncWebhookEventJob.perform_now(event_id)
      nil
    rescue StandardError => e
      Rails.logger.error("External folder sync webhook reconciliation failed event_id=#{event_id}: #{e.class}: #{e.message}")
      e
    end
    raise errors.first if errors.any?
  end

  private

  def converge_terminal_run_events!(limit)
    terminal_statuses = ExternalFolderSyncRun.statuses.values_at("completed", "failed", "partial")
    event_ids = ExternalFolderSyncWebhookEvent
      .processing
      .joins(:external_folder_sync_run)
      .where(external_folder_sync_runs: {status: terminal_statuses})
      .order(:updated_at, :id)
      .limit(limit)
      .pluck(:id)

    event_ids.each do |event_id|
      ExternalFolderSyncWebhookEvent.transaction do
        event = ExternalFolderSyncWebhookEvent.lock.find_by(id: event_id)
        run = event&.external_folder_sync_run
        next unless event&.processing?
        next unless run && !run.pending? && !run.running?

        ExternalFolderSync::WebhookEventResultRecorder.call(event:, run:)
      end
    end
  end

  def recover_legacy_stale_deliveries!(limit)
    recover_legacy_stale_enqueued!(limit)
    recover_legacy_stale_processing!(limit)
  end

  def recover_legacy_stale_enqueued!(limit)
    ids = ExternalFolderSyncWebhookEvent.stale_enqueued
      .where(external_folder_sync_run_id: nil)
      .order(:updated_at, :id)
      .limit(limit)
      .pluck(:id)

    ExternalFolderSyncWebhookEvent.where(id: ids, status: :enqueued, external_folder_sync_run_id: nil).update_all(
      status: ExternalFolderSyncWebhookEvent.statuses[:received],
      error_message: ExternalFolderSyncWebhookEvent::STALE_DELIVERY_RECOVERED_ERROR_MESSAGE,
      updated_at: Time.current
    )
  end

  def recover_legacy_stale_processing!(limit)
    ExternalFolderSyncWebhookEvent.stale_processing
      .where(external_folder_sync_run_id: nil)
      .order(:updated_at, :id)
      .limit(limit)
      .pluck(:id)
      .each do |event_id|
        ExternalFolderSyncWebhookEvent.transaction do
          event = ExternalFolderSyncWebhookEvent.lock.find_by(id: event_id)
          next unless event&.processing?
          next if event.external_folder_sync_run_id.present?
          next unless event.updated_at <= ExternalFolderSyncWebhookEvent::DELIVERY_STALE_AFTER.ago

          event.update!(
            status: :received,
            error_message: ExternalFolderSyncWebhookEvent::STALE_DELIVERY_RECOVERED_ERROR_MESSAGE
          )
        end
      end
  end
end
