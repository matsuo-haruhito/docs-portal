module DocumentDeliveryLogs
  class FailureAlertHandoff
    FAILED_DELIVERY_LOGS_PATH = "/document_delivery_logs"
    RUNBOOK_PATH = "docs/外部送付履歴継続失敗候補runbook.md"
    DELIVERY_LOG_QUERY_MAX_LENGTH = 100
    DEFAULT_PREVIEW_MAX_LENGTH = 80
    DEFAULT_ERROR_MESSAGE_MAX_LENGTH = 160

    Entry = Data.define(
      :identity,
      :project_code,
      :project_name,
      :delivery_type,
      :recipient_preview,
      :subject_preview,
      :failure_count,
      :last_failed_at,
      :latest_error_message,
      :failed_delivery_logs_path,
      :runbook_path
    ) do
      def project_id = identity.fetch(:project_id)
      def to_addresses = identity.fetch(:to_addresses)
      def subject = identity.fetch(:subject)

      def to_h
        {
          identity: identity,
          project_code: project_code,
          project_name: project_name,
          delivery_type: delivery_type,
          recipient_preview: recipient_preview,
          subject_preview: subject_preview,
          failure_count: failure_count,
          last_failed_at: last_failed_at,
          latest_error_message: latest_error_message,
          failed_delivery_logs_path: failed_delivery_logs_path,
          runbook_path: runbook_path
        }
      end
    end

    def initialize(
      candidates: nil,
      relation: DocumentDeliveryLog.all,
      threshold: FailureAlertCandidates::DEFAULT_THRESHOLD,
      limit: FailureAlertCandidates::DEFAULT_LIMIT,
      lookback_limit: nil,
      preview_max_length: DEFAULT_PREVIEW_MAX_LENGTH,
      error_message_max_length: DEFAULT_ERROR_MESSAGE_MAX_LENGTH
    )
      @candidates = candidates
      @relation = relation
      @threshold = threshold
      @limit = limit
      @lookback_limit = lookback_limit
      @preview_max_length = preview_max_length
      @error_message_max_length = error_message_max_length
    end

    def call
      candidate_source.map do |candidate|
        Entry.new(
          identity: candidate.identity,
          project_code: candidate.project.code,
          project_name: candidate.project.name,
          delivery_type: candidate.delivery_type,
          recipient_preview: preview(candidate.to_addresses),
          subject_preview: preview(candidate.subject),
          failure_count: candidate.failure_count,
          last_failed_at: candidate.last_failed_at,
          latest_error_message: error_message_preview(candidate.latest_error_message),
          failed_delivery_logs_path: failed_delivery_logs_path(candidate),
          runbook_path: RUNBOOK_PATH
        )
      end
    end

    private

    attr_reader :candidates, :relation, :threshold, :limit, :lookback_limit, :preview_max_length, :error_message_max_length

    def candidate_source
      candidates || FailureAlertCandidates.new(
        relation: relation,
        threshold: threshold,
        limit: limit,
        lookback_limit: lookback_limit
      ).call
    end

    def failed_delivery_logs_path(candidate)
      query = {
        status: "failed",
        delivery_type: candidate.delivery_type,
        q: candidate.subject.to_s.truncate(DELIVERY_LOG_QUERY_MAX_LENGTH, omission: "")
      }.compact_blank

      "#{FAILED_DELIVERY_LOGS_PATH}?#{query.to_query}"
    end

    def preview(value)
      return if value.blank?

      value.to_s.squish.truncate(preview_max_length, omission: "...")
    end

    def error_message_preview(message)
      return if message.blank?

      message.to_s.squish.truncate(error_message_max_length, omission: "...")
    end
  end
end
