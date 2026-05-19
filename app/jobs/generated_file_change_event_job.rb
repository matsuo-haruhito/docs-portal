class GeneratedFileChangeEventJob < ApplicationJob
  queue_as :default

  def perform(changed_files:, event_source: nil, metadata: {})
    GeneratedFiles::ChangeEventHandler.new(
      changed_files:,
      event_source:,
      metadata:
    ).call
  end
end
