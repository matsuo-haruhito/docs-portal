module GeneratedFiles
  class RunFailureAlertHandoff
    FAILED_RUNS_PATH = "/admin/generated_file_runs?status=failed"
    RUNBOOK_PATH = "docs/生成ファイル継続失敗候補runbook.md"
    DEFAULT_ERROR_MESSAGE_MAX_LENGTH = 160

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

      message.to_s.squish.truncate(error_message_max_length, omission: "...")
    end
  end
end
