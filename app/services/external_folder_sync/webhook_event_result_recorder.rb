module ExternalFolderSync
  class WebhookEventResultRecorder
    def self.call(event:, run:)
      recorded = false

      event.with_lock do
        run.reload
        next unless event.processing?
        next unless event.external_folder_sync_run_id == run.id
        next if run.pending? || run.running?

        event.update!(
          status: status_for(run),
          error_message: message_for(run),
          payload_json: event.payload_json.to_h.merge("sync_run" => run_summary(run))
        )
        recorded = true
      end

      recorded
    end

    def self.status_for(run)
      run.failed? || run.partial? ? :failed : :completed
    end

    def self.message_for(run)
      return run.error_message if run.error_message.present?
      return "競合警告があるため外部フォルダ同期を停止しました。" if run.summary_json&.fetch("blocked_by_conflict_warnings", false)
      return "外部フォルダ同期は#{run.errors_count}件のエラーを含んで完了しました。" if run.errors_count.to_i.positive?

      nil
    end

    def self.run_summary(run)
      {
        "id" => run.id,
        "public_id" => run.public_id,
        "status" => run.status,
        "mode" => run.mode,
        "started_at" => run.started_at&.iso8601,
        "finished_at" => run.finished_at&.iso8601,
        "items_scanned_count" => run.items_scanned_count,
        "errors_count" => run.errors_count,
        "conflict_warnings_count" => run.summary_json&.fetch("conflict_warnings_count", nil),
        "blocked_by_conflict_warnings" => run.summary_json&.fetch("blocked_by_conflict_warnings", false)
      }.compact
    end

    private_class_method :status_for, :message_for, :run_summary
  end
end
