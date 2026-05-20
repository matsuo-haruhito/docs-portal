module GeneratedFiles
  class EventBuffer
    DEFAULT_DEBOUNCE_SECONDS = 10

    def initialize(debounce_seconds: DEFAULT_DEBOUNCE_SECONDS, dispatcher_job: GeneratedFileEventDispatchJob)
      @debounce_seconds = debounce_seconds.to_i
      @dispatcher_job = dispatcher_job
    end

    def add(file_events:, event_source: nil, metadata: {})
      now = Time.current
      scheduled_at = now + debounce_seconds.seconds
      events = Array(file_events).filter_map { normalize_event(_1) }

      buffered = events.map do |event|
        key = GeneratedFileEvent.build_event_key(
          path: event.fetch(:path),
          operation: event.fetch(:operation),
          event_source: event_source
        )

        GeneratedFileEvent.transaction do
          record = GeneratedFileEvent.pending.lock.find_by(event_key: key) || GeneratedFileEvent.new(event_key: key)
          record.path = event.fetch(:path)
          record.operation = event.fetch(:operation)
          record.event_source = event_source
          record.metadata = merge_metadata(record.metadata, metadata)
          record.scheduled_at = scheduled_at
          record.last_seen_at = now
          record.occurrences_count = record.persisted? ? record.occurrences_count + 1 : 1
          record.status = :pending
          record.save!
          record
        end
      end

      dispatcher_job.set(wait: debounce_seconds.seconds).perform_later if buffered.any?
      buffered
    end

    private

    attr_reader :debounce_seconds, :dispatcher_job

    def normalize_event(event)
      if event.respond_to?(:fetch)
        path = event.fetch("path") { event.fetch(:path) }
        operation = event.fetch("operation") { event.fetch(:operation, "update") }
      else
        path = event
        operation = "update"
      end

      raw_path = path.to_s.strip.tr("\\", "/")
      normalized_path = Pathname(raw_path).cleanpath.to_s.delete_prefix("./")
      return if unsafe_path?(raw_path) || unsafe_path?(normalized_path)

      {
        path: normalized_path,
        operation: operation.to_s.presence || "update"
      }
    end

    def unsafe_path?(path)
      path.blank? ||
        path == "." ||
        path == ".." ||
        path.start_with?("/") ||
        path.match?(%r{\A[A-Za-z]:/}) ||
        path.split("/").include?("..")
    end

    def merge_metadata(existing, incoming)
      (existing || {}).merge(incoming || {})
    end
  end
end
