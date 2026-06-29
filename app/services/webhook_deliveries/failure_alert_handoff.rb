module WebhookDeliveries
  class FailureAlertHandoff
    FAILED_DELIVERIES_BASE_PATH = "/admin/webhook_deliveries"
    RUNBOOK_PATH = "docs/Webhook設定・送信失敗確認runbook.md"
    DEFAULT_ERROR_MESSAGE_MAX_LENGTH = 160
    FILTERED_VALUE = "[FILTERED]"
    SECRET_LIKE_KEY_PATTERN = /\b(token|access_token|refresh_token|secret|client_secret|api[_-]?key|password)\b\s*([=:])\s*([^&\s,;]+)/i
    AUTHORIZATION_VALUE_PATTERN = /\b(Authorization)\s*:\s*(Bearer|Basic)\s+[^,\s;]+/i
    AUTH_SCHEME_VALUE_PATTERN = /\b(Bearer|Basic)\s+[^,\s;]+/i
    PRIVATE_PATH_PATTERN = %r{(?<![A-Za-z0-9])/(?:home|Users|var|tmp|workspace|app|srv|etc)/[^\s,;]+}

    Entry = Data.define(
      :identity,
      :endpoint_name,
      :endpoint_active,
      :event_type,
      :target_url_preview,
      :response_status,
      :failure_count,
      :last_failed_at,
      :latest_error_message,
      :failed_deliveries_path,
      :runbook_path
    ) do
      def to_h
        {
          identity: identity,
          endpoint_name: endpoint_name,
          endpoint_active: endpoint_active,
          event_type: event_type,
          target_url_preview: target_url_preview,
          response_status: response_status,
          failure_count: failure_count,
          last_failed_at: last_failed_at,
          latest_error_message: latest_error_message,
          failed_deliveries_path: failed_deliveries_path,
          runbook_path: runbook_path
        }
      end
    end

    def initialize(
      candidates: nil,
      relation: WebhookDelivery.all,
      threshold: FailureAlertCandidates::DEFAULT_THRESHOLD,
      limit: FailureAlertCandidates::DEFAULT_LIMIT,
      lookback_limit: FailureAlertCandidates::DEFAULT_LOOKBACK_LIMIT,
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
          identity: handoff_identity(candidate),
          endpoint_name: candidate.webhook_endpoint.name,
          endpoint_active: candidate.webhook_endpoint.active?,
          event_type: candidate.event_type,
          target_url_preview: candidate.target_url_preview,
          response_status: candidate.latest_response_status,
          failure_count: candidate.failure_count,
          last_failed_at: candidate.last_failed_at,
          latest_error_message: error_message_preview(candidate.latest_error_message),
          failed_deliveries_path: failed_deliveries_path(candidate),
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

    def handoff_identity(candidate)
      {
        webhook_endpoint_id: candidate.webhook_endpoint_id,
        event_type: candidate.event_type,
        target_url_preview: candidate.target_url_preview
      }
    end

    def failed_deliveries_path(candidate)
      query = {
        webhook_endpoint_id: candidate.webhook_endpoint_id,
        event_type: candidate.event_type,
        status: "failed",
        response_status: candidate.latest_response_status
      }.compact_blank

      "#{FAILED_DELIVERIES_BASE_PATH}?#{query.to_query}"
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
