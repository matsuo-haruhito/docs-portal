class GeneratedFileJob < ApplicationJob
  queue_as :default

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(*args, **kwargs) { concurrency_key_for(args:, kwargs:) },
      duration: 10.minutes
  end

  def self.concurrency_key_for(args:, kwargs:)
    payload = kwargs.presence || args.first || {}
    job_ids = Array(payload[:job_ids] || payload["job_ids"]).filter_map { normalized_token_for(_1) }.sort
    changed_files = Array(payload[:changed_files] || payload["changed_files"]).filter_map { normalized_path_for(_1) }.sort

    if job_ids.any?
      "generated-file-job:ids:#{job_ids.join(',')}"
    else
      "generated-file-job:files:#{changed_files.join(',')}"
    end
  end

  def self.normalized_token_for(value)
    value.to_s.strip.presence
  end

  def self.normalized_path_for(path)
    normalized = Pathname(path.to_s.strip).cleanpath.to_s.delete_prefix("./")
    return nil if normalized.blank? || normalized == "."

    normalized
  end

  def perform(changed_files: [], job_ids: [], event_source: nil, metadata: {})
    safe_metadata = metadata || {}

    Rails.logger.info(
      "GeneratedFileJob started: event_source=#{event_source.inspect} " \
      "job_ids=#{Array(job_ids).join(',')} changed_files=#{Array(changed_files).join(',')} " \
      "metadata=#{safe_metadata.to_h.inspect}"
    )

    GeneratedFiles::Runner.new(
      changed_files:,
      job_ids:,
      event_source:,
      metadata: safe_metadata
    ).call
  end
end
