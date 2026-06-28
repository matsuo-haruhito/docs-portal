module ExternalFolderSyncRuns
  class FailureAlertCandidates
    DEFAULT_THRESHOLD = 3
    DEFAULT_LIMIT = 20
    DEFAULT_ERROR_MESSAGE_MAX_LENGTH = 160
    FILTERED_VALUE = "[FILTERED]"
    SECRET_LIKE_KEY_PATTERN = /\b(token|access_token|refresh_token|secret|client_secret|api[_-]?key|password)\b\s*([=:])\s*([^&\s,;]+)/i
    AUTHORIZATION_VALUE_PATTERN = /\b(Authorization)\s*:\s*(Bearer|Basic)\s+[^,\s;]+/i
    AUTH_SCHEME_VALUE_PATTERN = /\b(Bearer|Basic)\s+[^,\s;]+/i
    PRIVATE_PATH_PATTERN = %r{(?<![A-Za-z0-9])/(?:home|Users|var|tmp|workspace|app|srv|etc)/[^\s,;]+}
    SIGNED_URL_PATTERN = %r{https?://[^\s,;]*(?:X-Amz-Signature|signature|sig|token|access_token|client_secret)=[^\s,;]+}i

    Candidate = Data.define(
      :identity,
      :source,
      :runs,
      :failure_count,
      :last_failed_at,
      :latest_error_message,
      :source_path
    ) do
      def external_folder_sync_source_id = identity.fetch(:external_folder_sync_source_id)
      def provider = identity.fetch(:provider)
      def source_name = source.name
      def project = source.project
      def project_code = project.code
      def project_name = project.name
    end

    def initialize(
      relation: ExternalFolderSyncRun.all,
      threshold: DEFAULT_THRESHOLD,
      limit: DEFAULT_LIMIT,
      lookback_limit: nil,
      error_message_max_length: DEFAULT_ERROR_MESSAGE_MAX_LENGTH
    )
      @relation = relation
      @threshold = threshold
      @limit = limit
      @lookback_limit = lookback_limit
      @error_message_max_length = error_message_max_length
    end

    def call
      grouped_latest_runs.filter_map do |identity, runs|
        candidate_for(identity, runs)
      end.sort_by { |candidate| candidate.last_failed_at || Time.zone.at(0) }.reverse.first(limit)
    end

    private

    attr_reader :relation, :threshold, :limit, :lookback_limit, :error_message_max_length

    def grouped_latest_runs
      ordered_runs.group_by { |run| identity_for(run) }
    end

    def ordered_runs
      scope = relation.includes(external_folder_sync_source: :project).order(started_at: :desc, created_at: :desc, id: :desc)
      lookback_limit ? scope.limit(lookback_limit) : scope
    end

    def candidate_for(identity, runs)
      consecutive_failures = runs.take_while { |run| run.failed? || run.partial? }
      return if consecutive_failures.size < threshold

      latest_failure = consecutive_failures.first
      source = latest_failure.external_folder_sync_source

      Candidate.new(
        identity: identity,
        source: source,
        runs: consecutive_failures,
        failure_count: consecutive_failures.size,
        last_failed_at: latest_failure.finished_at || latest_failure.started_at || latest_failure.updated_at || latest_failure.created_at,
        latest_error_message: error_message_preview(latest_failure.error_message.presence || source.last_error_message),
        source_path: "/admin/external_folder_sync_sources/#{source.to_param}"
      )
    end

    def identity_for(run)
      source = run.external_folder_sync_source

      {
        external_folder_sync_source_id: run.external_folder_sync_source_id,
        provider: source.provider
      }
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
