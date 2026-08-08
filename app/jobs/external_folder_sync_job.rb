class ExternalFolderSyncJob < ApplicationJob
  queue_as :default

  class << self
    def enqueue_for(source:, actor: source.created_by)
      return perform_later(source.id, actor&.id) unless JobReliability::RolloutGate.enabled?

      run = ExternalFolderSync::RunLease.reserve!(source:, mode: :apply, recover_stale: true)
      return unless run

      job = perform_later(source.id, actor&.id, nil, run.id)
      raise "External folder sync job could not be enqueued" unless job

      job
    rescue StandardError => e
      ExternalFolderSync::RunLease.fail!(run, error: e) if run
      raise
    end
  end

  def perform(external_folder_sync_source_id, actor_id = nil, webhook_event_id = nil, external_folder_sync_run_id = nil)
    return if read_only_maintenance?
    return if external_folder_sync_run_id.present? && !JobReliability::RolloutGate.enabled?

    source = ExternalFolderSyncSource.find(external_folder_sync_source_id)
    actor = actor_id.present? ? User.find(actor_id) : source.created_by
    run = resolve_run(source, webhook_event_id:, external_folder_sync_run_id:)
    return unless run

    webhook_event = ExternalFolderSyncWebhookEvent.find_by(id: webhook_event_id) if webhook_event_id.present?
    if webhook_event
      webhook_events = claim_webhook_events(webhook_event, run)
      return if webhook_events.blank?
    else
      return unless ExternalFolderSync::RunLease.claim!(run)

      webhook_events = []
    end

    finished_run = ExternalFolderSync::Runner.new(source:, mode: :apply, actor:, run:).call
    webhook_events.each { reflect_webhook_event_result!(_1, finished_run) }
  rescue ExternalFolderSync::RunLease::StaleClaimError => e
    Rails.logger.info("ExternalFolderSyncJob: stale owner stopped: #{e.message}")
    nil
  rescue StandardError => e
    if defined?(run) && run
      run.reload
      if run.pending? || run.running?
        unless ExternalFolderSync::RunLease.fail!(run, error: e)
          Rails.logger.info("ExternalFolderSyncJob: failure ignored after lease replacement: #{e.message}")
          return nil
        end
      end
    end
    if defined?(run) && run
      Array(webhook_events).each do |event|
        ExternalFolderSync::WebhookEventResultRecorder.call(event:, run:)
      end
    end
    raise
  end

  private

  def resolve_run(source, webhook_event_id:, external_folder_sync_run_id:)
    if external_folder_sync_run_id.present?
      return source.external_folder_sync_runs.find_by(id: external_folder_sync_run_id)
    end

    recover_stale = JobReliability::RolloutGate.enabled?
    if webhook_event_id.blank?
      return ExternalFolderSync::RunLease.reserve!(source:, mode: :apply, recover_stale:)
    end

    reserve_legacy_webhook_run(source, webhook_event_id, recover_stale:)
  end

  def reserve_legacy_webhook_run(source, webhook_event_id, recover_stale:)
    representative = source.external_folder_sync_webhook_events.find_by(id: webhook_event_id)
    return unless representative

    ExternalFolderSync::RunLease.reserve!(source:, mode: :apply, recover_stale:) do |reserved_run|
      event_ids = coalesced_webhook_event_ids(representative)
      events = source.external_folder_sync_webhook_events.where(id: event_ids).lock.to_a
      current_representative = events.find { _1.id == representative.id }
      next false unless current_representative&.external_folder_sync_run_id.nil?
      next false unless current_representative.enqueued? || current_representative.received?

      events.each do |event|
        next unless event.external_folder_sync_run_id.nil?
        next unless event.enqueued? || event.received?

        event.update!(external_folder_sync_run: reserved_run, status: :enqueued)
      end
      true
    end
  end

  def claim_webhook_events(representative, run)
    claimed_events = []
    claimed = ExternalFolderSync::RunLease.claim!(run) do
      event_ids = coalesced_webhook_event_ids(representative)
      events = ExternalFolderSyncWebhookEvent
        .where(id: event_ids, external_folder_sync_run_id: run.id)
        .order(:received_at, :id)
        .lock
        .to_a
      current_representative = events.find { _1.id == representative.id }
      next false unless current_representative&.enqueued?

      claimed_events = events.select(&:enqueued?)
      next false if claimed_events.empty?

      claimed_events.each { _1.update!(status: :processing, error_message: nil) }
      true
    end

    claimed ? claimed_events : []
  end

  def coalesced_webhook_event_ids(representative)
    ids = Array(representative.payload_json&.fetch("coalesced_webhook_event_ids", nil))
    ids << representative.id
    ids.compact.uniq
  end

  def reflect_webhook_event_result!(webhook_event, run)
    webhook_event.reload
    return unless webhook_event.processing?
    return unless webhook_event.external_folder_sync_run_id == run.id

    ExternalFolderSync::WebhookEventResultRecorder.call(event: webhook_event, run:)
  end
end
