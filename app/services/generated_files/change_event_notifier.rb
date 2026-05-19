module GeneratedFiles
  class ChangeEventNotifier
    def initialize(job_class: GeneratedFileChangeEventJob)
      @job_class = job_class
    end

    def notify(file_events:, event_source:, metadata: {})
      events = normalize_events(file_events)
      return [] if events.empty?

      job_class.perform_later(
        file_events: events,
        event_source: event_source,
        metadata: metadata || {}
      )
      events
    end

    private

    attr_reader :job_class

    def normalize_events(file_events)
      Array(file_events).filter_map do |event|
        if event.respond_to?(:fetch)
          path = event.fetch("path") { event.fetch(:path) }
          operation = event.fetch("operation") { event.fetch(:operation, "update") }
        else
          path = event
          operation = "update"
        end

        normalized_path = Pathname(path.to_s.strip).cleanpath.to_s.delete_prefix("./")
        next if normalized_path.blank?

        { path: normalized_path, operation: operation.to_s.presence || "update" }
      end.uniq
    end
  end
end
