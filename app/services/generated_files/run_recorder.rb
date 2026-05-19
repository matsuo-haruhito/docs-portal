module GeneratedFiles
  class RunRecorder
    def initialize(enabled: nil)
      @enabled = enabled
    end

    def start(job:, changed_files:, event_source: nil, metadata: {})
      return NullRun.new unless enabled?

      GeneratedFileRun.create!(
        job_id: job.fetch("id"),
        generator: job["generator"],
        output_writer: job["output_writer"],
        status: :running,
        event_source: event_source,
        source_paths: Array(job["source_paths"]),
        changed_files: Array(changed_files),
        generated_paths: [],
        metadata: metadata || {},
        started_at: Time.current
      )
    rescue => e
      Rails.logger.warn("Generated file run recording skipped: #{e.class}: #{e.message}") if defined?(Rails)
      NullRun.new
    end

    def enabled?
      return @enabled unless @enabled.nil?
      return false unless defined?(ActiveRecord::Base)
      return false unless defined?(GeneratedFileRun)
      return false unless ActiveRecord::Base.connected?

      GeneratedFileRun.table_exists?
    rescue
      false
    end

    class NullRun
      def finish!(status:, generated_paths: [], error_message: nil); end
    end
  end
end
