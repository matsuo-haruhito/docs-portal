class GeneratedFileEventDispatchJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(*) { "generated-file-event-dispatch" },
      duration: 20.minutes
  end

  def perform
    return if read_only_maintenance?
    return unless JobReliability::RolloutGate.enabled?

    claims = GeneratedFiles::EventDispatchLease.recover_stale_groups!(limit: BATCH_SIZE)
    remaining = BATCH_SIZE - claims.sum { _1.event_ids.size }
    claims.concat(claim_due_events(limit: remaining)) if remaining.positive?
    return if claims.empty?

    errors = claims.filter_map { dispatch_group(_1) }
    raise errors.first if errors.any?
  end

  private

  def claim_due_events(limit:)
    events = GeneratedFileEvent.due.order(:scheduled_at, :id).limit(limit).to_a
    grouped_events(events).filter_map do |_event_source, grouped|
      GeneratedFiles::EventDispatchLease.claim!(grouped)
    end
  end

  def dispatch_group(claim)
    events = GeneratedFiles::EventDispatchLease.events_for(claim)
    return if events.empty?
    return unless GeneratedFiles::EventDispatchLease.heartbeat!(claim)

    GeneratedFileChangeEventJob.perform_now(
      file_events: events.map { {path: _1.path, operation: _1.operation} },
      event_source: claim.event_source,
      metadata: dispatch_metadata(events, claim),
      dispatch_claim: claim
    )
    return unless GeneratedFiles::EventDispatchLease.heartbeat!(claim)

    GeneratedFiles::EventDispatchLease.complete!(claim)
    nil
  rescue StandardError => e
    GeneratedFiles::EventDispatchLease.fail!(claim, error: e) ? e : nil
  end

  def grouped_events(events)
    events.group_by(&:event_source)
  end

  def dispatch_metadata(events, claim)
    metadata = events.each_with_object({}) do |event, result|
      result.merge!(event.metadata || {})
    end
    metadata.merge(
      "generated_file_event_public_ids" => events.map(&:public_id),
      "generated_file_event_occurrences_count" => events.sum(&:occurrences_count),
      "generated_file_event_dispatch_group_id" => claim.group_id,
      "generated_file_idempotency_group_id" => claim.group_id
    )
  end
end
