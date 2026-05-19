class GeneratedFileChangeEventJob < ApplicationJob
  queue_as :default

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(*args, **kwargs) { concurrency_key_for(args:, kwargs:) },
      duration: 5.minutes
  end

  def self.concurrency_key_for(args:, kwargs:)
    payload = kwargs.presence || args.first || {}
    file_events = Array(payload[:file_events] || payload["file_events"])
    changed_files = Array(payload[:changed_files] || payload["changed_files"])
    operation = (payload[:operation] || payload["operation"] || :update).to_s

    normalized = if file_events.any?
      file_events.filter_map do |event|
        path = normalized_path_for(event.fetch("path") { event.fetch(:path) })
        next if path.blank?

        event_operation = event.fetch("operation") { event.fetch(:operation, :update) }
        event_operation = :update if event_operation.blank?
        "#{path}:#{event_operation}"
      end
    else
      changed_files.filter_map do |changed_file|
        path = normalized_path_for(changed_file)
        next if path.blank?

        "#{path}:#{operation}"
      end
    end

    "generated-file-change-event:#{normalized.sort.join(',')}"
  end

  def self.normalized_path_for(path)
    normalized = Pathname(path.to_s.strip).cleanpath.to_s.delete_prefix("./")
    return nil if unsafe_path?(normalized)

    normalized
  end

  def self.unsafe_path?(path)
    path.blank? ||
      path == "." ||
      path.start_with?("/") ||
      path.match?(%r{\A[A-Za-z]:/}) ||
      path.split("/").include?("..")
  end

  def perform(changed_files: nil, file_events: nil, operation: :update, event_source: nil, metadata: {}, debounce_seconds: nil)
    if debounce_seconds.to_i.positive?
      GeneratedFiles::EventBuffer.new(debounce_seconds:).add(
        file_events: normalize_buffer_events(file_events:, changed_files:, operation:),
        event_source:,
        metadata:
      )
      return
    end

    GeneratedFiles::ChangeEventHandler.new(
      changed_files:,
      file_events:,
      operation:,
      event_source:,
      metadata:
    ).call
  end

  private

  def normalize_buffer_events(file_events:, changed_files:, operation:)
    return file_events if Array(file_events).any?

    Array(changed_files).filter_map do |changed_file|
      path = self.class.normalized_path_for(changed_file)
      next if path.blank?

      { path: path, operation: operation }
    end
  end
end
