class GeneratedFileEventDispatchJob < ApplicationJob
  queue_as :default

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(*) { "generated-file-event-dispatch" },
      duration: 5.minutes
  end

  def perform
    events = GeneratedFileEvent.due.order(:scheduled_at, :id).to_a
    return if events.empty?

    events.each { _1.update!(status: :processing) }

    grouped_events(events).each do |event_source, grouped|
      GeneratedFileChangeEventJob.perform_later(
        file_events: grouped.map { { path: _1.path, operation: _1.operation } },
        event_source: event_source,
        metadata: dispatch_metadata(grouped)
      )
    end

    events.each(&:mark_processed!)
  rescue => e
    Array(events).each { _1.mark_failed!(e.message) } if defined?(events) && events.present?
    raise
  end

  private

  def grouped_events(events)
    events.group_by(&:event_source)
  end

  def dispatch_metadata(events)
    metadata = events.each_with_object({}) do |event, result|
      result.merge!(event.metadata || {})
    end
    metadata.merge(
      "generated_file_event_public_ids" => events.map(&:public_id),
      "generated_file_event_occurrences_count" => events.sum(&:occurrences_count)
    )
  end
end
