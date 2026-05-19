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
      file_events.map do |event|
        path = event.fetch("path") { event.fetch(:path) }
        event_operation = event.fetch("operation") { event.fetch(:operation) }
        "#{Pathname(path.to_s).cleanpath}:#{event_operation}"
      end
    else
      changed_files.map { "#{Pathname(_1.to_s).cleanpath}:#{operation}" }
    end

    "generated-file-change-event:#{normalized.sort.join(',')}"
  end

  def perform(changed_files: nil, file_events: nil, operation: :update, event_source: nil, metadata: {})
    GeneratedFiles::ChangeEventHandler.new(
      changed_files:,
      file_events:,
      operation:,
      event_source:,
      metadata:
    ).call
  end
end
