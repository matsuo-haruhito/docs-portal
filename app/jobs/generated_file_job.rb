class GeneratedFileJob < ApplicationJob
  queue_as :default

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(*args, **kwargs) { concurrency_key_for(args:, kwargs:) },
      duration: 10.minutes
  end

  def self.concurrency_key_for(args:, kwargs:)
    payload = kwargs.presence || args.first || {}
    job_ids = Array(payload[:job_ids] || payload["job_ids"]).map(&:to_s).sort
    changed_files = Array(payload[:changed_files] || payload["changed_files"]).map(&:to_s).sort

    if job_ids.any?
      "generated-file-job:ids:#{job_ids.join(',')}"
    else
      "generated-file-job:files:#{changed_files.join(',')}"
    end
  end

  def perform(changed_files: [], job_ids: [], event_source: nil, metadata: {})
    Rails.logger.info(
      "GeneratedFileJob started: event_source=#{event_source.inspect} " \
      "job_ids=#{Array(job_ids).join(',')} changed_files=#{Array(changed_files).join(',')} " \
      "metadata=#{metadata.to_h.inspect}"
    )

    GeneratedFiles::Runner.new(
      changed_files:,
      job_ids:,
      event_source:,
      metadata:
    ).call
  end
end
