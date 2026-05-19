class GeneratedFileChangeEventJob < ApplicationJob
  queue_as :default

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
