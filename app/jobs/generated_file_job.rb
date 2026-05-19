class GeneratedFileJob < ApplicationJob
  queue_as :default

  def perform(changed_files: [], job_ids: [], event_source: nil, metadata: {})
    Rails.logger.info(
      "GeneratedFileJob started: event_source=#{event_source.inspect} " \
      "job_ids=#{Array(job_ids).join(',')} changed_files=#{Array(changed_files).join(',')} " \
      "metadata=#{metadata.to_h.inspect}"
    )

    GeneratedFiles::Runner.new(changed_files:, job_ids:).call
  end
end
