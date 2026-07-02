module ExternalFolderSyncRuns
  class FailureAlertHandoff
    ERROR_SOURCES_PATH = "/admin/external_folder_sync_sources?review=errors"
    RUNBOOK_PATH = "docs/外部フォルダ同期継続失敗候補runbook.md"
    DEFAULT_ERROR_MESSAGE_MAX_LENGTH = 160
    FILTERED_VALUE = "[FILTERED]"
    SECRET_LIKE_KEY_PATTERN = /\b(token|access_token|refresh_token|secret|client_secret|api[_-]?key|password)\b\s*([=:])\s*([^&\s,;]+)/i
    AUTHORIZATION_VALUE_PATTERN = /\b(Authorization)\s*:\s*(Bearer|Basic)\s+[^,\s;]+/i
    AUTH_SCHEME_VALUE_PATTERN = /\b(Bearer|Basic)\s+[^,\s;]+/i
    PRIVATE_PATH_PATTERN = %r{(?<![A-Za-z0-9])/(?:home|Users|var|tmp|workspace|app|srv|etc)/[^\s,;]+}
    SIGNED_URL_PATTERN = %r{https?://[^\s,;]*(?:X-Amz-Signature|signature|sig|token|access_token|client_secret)=[^\s,;]+}i

    Entry = Data.define(
      :source_name,
      :provider,
      :project_code,
      :project_name,
      :failure_count,
      :last_failed_at,
      :latest_error_message,
      :source_path,
      :runbook_path
    ) do
      def to_h
        {
          source_name: source_name,
          provider: provider,
          project_code: project_code,
          project_name: project_name,
          failure_count: failure_count,
          last_failed_at: last_failed_at,
          latest_error_message: latest_error_message,
          source_path: source_path,
          runbook_path: runbook_path
        }
      end
    end

    def self.markdown(entries)
      lines = [
        "## 外部フォルダ同期継続失敗候補 digest",
        "",
        "通知・ack・SLA・自動 retry・provider 正常判定の状態ではない read-only preview です。",
        ""
      ]

      if entries.empty?
        lines << "候補 0 件です。現在の抽出条件で通知前に渡す対象はありません。外部 provider 全体正常、通知済み、ack 済み、自動 retry 済みを意味しません。"
      else
        entries.each do |entry|
          lines << "- source: #{entry.source_name.presence || '-'}"
          lines << "  - provider: #{entry.provider.presence || '-'}"
          lines << "  - project: #{entry.project_code.presence || '-'} #{entry.project_name.presence || '-'}"
          lines << "  - consecutive_failed_or_partial: #{entry.failure_count}"
          lines << "  - last_failed_at: #{entry.last_failed_at&.iso8601 || '-'}"
          lines << "  - error_preview: #{entry.latest_error_message.presence || '-'}"
          lines << "  - source_path: #{entry.source_path}"
          lines << "  - runbook_path: #{entry.runbook_path}"
        end
      end

      lines << ""
      lines << "All error sources: #{ERROR_SOURCES_PATH}"
      lines << "Runbook: #{RUNBOOK_PATH}"
      lines.join("\n")
    end

    def initialize(
      candidates: nil,
      relation: ExternalFolderSyncRun.all,
      threshold: FailureAlertCandidates::DEFAULT_THRESHOLD,
      limit: FailureAlertCandidates::DEFAULT_LIMIT,
      lookback_limit: nil,
      error_message_max_length: DEFAULT_ERROR_MESSAGE_MAX_LENGTH
    )
      @candidates = candidates
      @relation = relation
      @threshold = threshold
      @limit = limit
      @lookback_limit = lookback_limit
      @error_message_max_length = error_message_max_length
    end

    def call
      candidate_source.map do |candidate|
        Entry.new(
          source_name: candidate.source_name,
          provider: candidate.provider,
          project_code: candidate.project_code,
          project_name: candidate.project_name,
          failure_count: candidate.failure_count,
          last_failed_at: candidate.last_failed_at,
          latest_error_message: error_message_preview(candidate.latest_error_message),
          source_path: candidate.source_path,
          runbook_path: RUNBOOK_PATH
        )
      end
    end

    private

    attr_reader :candidates, :relation, :threshold, :limit, :lookback_limit, :error_message_max_length

    def candidate_source
      candidates || FailureAlertCandidates.new(
        relation: relation,
        threshold: threshold,
        limit: limit,
        lookback_limit: lookback_limit
      ).call
    end

    def error_message_preview(message)
      return if message.blank?

      mask_sensitive_error_message(message).squish.truncate(error_message_max_length, omission: "...")
    end

    def mask_sensitive_error_message(message)
      message.to_s
        .gsub(SIGNED_URL_PATTERN, "[url omitted]")
        .gsub(AUTHORIZATION_VALUE_PATTERN) { "#{$1}: #{$2} #{FILTERED_VALUE}" }
        .gsub(AUTH_SCHEME_VALUE_PATTERN) { "#{$1} #{FILTERED_VALUE}" }
        .gsub(SECRET_LIKE_KEY_PATTERN) { "#{$1}#{$2}#{FILTERED_VALUE}" }
        .gsub(PRIVATE_PATH_PATTERN, "[path omitted]")
    end
  end
end
