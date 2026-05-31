module GeneratedFiles
  class AutoRetryPolicy
    TARGET_JOB_ID = "ai_usecase_decision_flow"
    TARGET_GENERATOR = "ai_usecase_decision_flow"
    TARGET_OUTPUT_WRITER = "filesystem"
    EVENT_SOURCE = "generated_file_run_auto_retry"
    RETRY_REASON = "auto_retry_generated_file_run_failed"

    def enqueue_for(run)
      return false unless eligible?(run)

      GeneratedFileJob.perform_later(
        changed_files: Array(run.changed_files),
        job_ids: [run.job_id],
        event_source: EVENT_SOURCE,
        metadata: retry_metadata_for(run)
      )
      true
    rescue => error
      Rails.logger.warn("Generated file auto retry skipped: #{error.class}: #{error.message}") if defined?(Rails)
      false
    end

    private

    def eligible?(run)
      return false unless defined?(GeneratedFileRun) && defined?(GeneratedFileJob)
      return false unless run.respond_to?(:public_id) && run.public_id.to_s.strip != ""
      return false unless failed?(run)
      return false unless target_run?(run)
      return false if retry_run?(run)
      return false if auto_retry_child_exists?(run)

      true
    end

    def failed?(run)
      run.respond_to?(:failed?) ? run.failed? : run.status.to_s == "failed"
    end

    def target_run?(run)
      run.job_id == TARGET_JOB_ID &&
        run.generator == TARGET_GENERATOR &&
        run.output_writer == TARGET_OUTPUT_WRITER
    end

    def retry_run?(run)
      retry_parent = metadata_for(run)["retry_of_generated_file_run_public_id"]
      retry_parent.to_s.strip != ""
    end

    def auto_retry_child_exists?(run)
      GeneratedFileRun
        .where.not(id: run.id)
        .where(job_id: run.job_id)
        .any? { |candidate| auto_retry_child_for?(candidate, run) }
    end

    def auto_retry_child_for?(candidate, parent_run)
      metadata = metadata_for(candidate)
      metadata["retry_of_generated_file_run_public_id"] == parent_run.public_id && metadata["auto_retry"] == true
    end

    def retry_metadata_for(run)
      metadata_for(run).merge(
        "retry_of_generated_file_run_public_id" => run.public_id,
        "retry_requested_at" => Time.current.iso8601,
        "retry_requested_by_user_id" => nil,
        "auto_retry" => true,
        "retry_reason" => RETRY_REASON
      ).compact
    end

    def metadata_for(run)
      run.metadata || {}
    end
  end
end
