module GeneratedFiles
  class RunFailureAlertHandoff
    FAILED_RUNS_PATH = "/admin/generated_file_runs?status=failed"
    FAILED_RUNS_BASE_PATH = "/admin/generated_file_runs"
    RUNBOOK_PATH = "docs/生成ファイル継続失敗候補runbook.md"
    DEFAULT_ERROR_MESSAGE_MAX_LENGTH = 160
    FILTERED_VALUE = "[FILTERED]"
    SECRET_LIKE_KEY_PATTERN = /\b(token|access_token|refresh_token|secret|client_secret|api[_-]?key|authorization|password)\b\s*([=:])\s*([^&\s,;]+)/i
    AUTHORIZATION_VALUE_PATTERN = /\b(Authorization)\s*:\s*(Bearer|Basic)\s+[^,\s;]+/i
    AUTH_SCHEME_VALUE_PATTERN = /\b(Bearer|Basic)\s+[^,\s;]+/i
    PRIVATE_PATH_PATTERN = %r{(?<![A-Za-z0-9])/(?:home|Users|var|tmp|workspace|app|srv|etc)/[^\s,;]+}

    Entry = Data.define(
      :identity,
      :failure_count,
      :last_failed_at,
      :latest_error_message,
      :failed_runs_path,
      :runbook_path
    ) do
      def job_id = identity.fetch(:job_id)
      def generator = identity[:generator]
      def output_writer = identity[:output_writer]
      def event_source = identity[:event_source]
      def filtered_failed_runs_path = RunFailureAlertHandoff.filtered_failed_runs_path(identity)

      def to_h
        {
          identity: identity,
          failure_count: failure_count,
          last_failed_at: last_failed_at,
          latest_error_message: latest_error_message,
          failed_runs_path: failed_runs_path,
          runbook_path: runbook_path
        }
      end
    end

    def self.markdown(entries)
      lines = [
        "## 生成ファイル継続失敗候補 digest",
        "",
        "通知・ack・SLA・自動 retry の状態ではない read-only preview です。",
        ""
      ]

      if entries.empty?
        lines << "候補 0 件です。現在の抽出条件で通知前に渡す対象はありません。正常保証、通知済み、ack 済み、自動 retry 済みを意味しません。"
      else
        entries.each do |entry|
          lines << "- identity: #{identity_label(entry.identity)}"
          lines << "  - consecutive_failures: #{entry.failure_count}"
          lines << "  - last_failed_at: #{entry.last_failed_at&.iso8601 || '-'}"
          lines << "  - error_preview: #{entry.latest_error_message.presence || '-'}"
          lines << "  - failed_runs_path: #{entry.filtered_failed_runs_path}"
          lines << "  - runbook_path: #{entry.runbook_path}"
        end
      end

      lines << ""
      lines << "Runbook: #{RUNBOOK_PATH}"
      lines.join("\n")
    end

    def self.filtered_failed_runs_path(identity)
      params = {
        status: "failed",
        job_id: identity[:job_id].presence,
        generator: identity[:generator].presence,
        output_writer: identity[:output_writer].presence,
        event_source: identity[:event_source].presence
      }.compact

      "#{FAILED_RUNS_BASE_PATH}?#{params.to_query}"
    end

    def self.identity_label(identity)
      [
        "job_id=#{identity.fetch(:job_id).presence || '-'}",
        ("generator=#{identity[:generator]}" if identity[:generator].present?),
        ("output_writer=#{identity[:output_writer]}" if identity[:output_writer].present?),
        ("event_source=#{identity[:event_source]}" if identity[:event_source].present?)
      ].compact.join(" / ")
    end

    def initialize(
      candidates: nil,
      relation: GeneratedFileRun.all,
      threshold: RunFailureAlertCandidates::DEFAULT_THRESHOLD,
      limit: RunFailureAlertCandidates::DEFAULT_LIMIT,
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
          identity: candidate.identity,
          failure_count: candidate.failure_count,
          last_failed_at: candidate.last_failed_at,
          latest_error_message: error_message_preview(candidate.latest_error_message),
          failed_runs_path: FAILED_RUNS_PATH,
          runbook_path: RUNBOOK_PATH
        )
      end
    end

    private

    attr_reader :candidates, :relation, :threshold, :limit, :lookback_limit, :error_message_max_length

    def candidate_source
      candidates || RunFailureAlertCandidates.new(
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
        .gsub(AUTHORIZATION_VALUE_PATTERN) { "#{$1}: #{$2} #{FILTERED_VALUE}" }
        .gsub(AUTH_SCHEME_VALUE_PATTERN) { "#{$1} #{FILTERED_VALUE}" }
        .gsub(SECRET_LIKE_KEY_PATTERN) { "#{$1}#{$2}#{FILTERED_VALUE}" }
        .gsub(PRIVATE_PATH_PATTERN, "[path omitted]")
    end
  end
end
