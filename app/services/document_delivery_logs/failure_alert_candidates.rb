module DocumentDeliveryLogs
  class FailureAlertCandidates
    DEFAULT_THRESHOLD = 3
    DEFAULT_LIMIT = 20

    Candidate = Data.define(
      :identity,
      :logs,
      :failure_count,
      :last_failed_at,
      :latest_error_message
    ) do
      def project_id = identity.fetch(:project_id)
      def delivery_type = identity.fetch(:delivery_type)
      def to_addresses = identity.fetch(:to_addresses)
      def subject = identity.fetch(:subject)
      def latest_log = logs.first
      def project = latest_log.project
    end

    def initialize(relation: DocumentDeliveryLog.all, threshold: DEFAULT_THRESHOLD, limit: DEFAULT_LIMIT, lookback_limit: nil)
      @relation = relation
      @threshold = threshold
      @limit = limit
      @lookback_limit = lookback_limit
    end

    def call
      grouped_latest_logs.filter_map do |identity, logs|
        candidate_for(identity, logs)
      end.sort_by { |candidate| candidate.last_failed_at || Time.zone.at(0) }.reverse.first(@limit)
    end

    private

    attr_reader :relation, :threshold, :limit, :lookback_limit

    def grouped_latest_logs
      ordered_logs.group_by do |log|
        identity_for(log)
      end
    end

    def ordered_logs
      scope = relation.includes(:project).order(created_at: :desc, id: :desc)
      lookback_limit ? scope.limit(lookback_limit) : scope
    end

    def candidate_for(identity, logs)
      consecutive_failures = logs.take_while(&:failed?)
      return if consecutive_failures.size < threshold

      latest_failure = consecutive_failures.first
      Candidate.new(
        identity: identity,
        logs: consecutive_failures,
        failure_count: consecutive_failures.size,
        last_failed_at: latest_failure.updated_at || latest_failure.created_at,
        latest_error_message: latest_failure.error_message
      )
    end

    def identity_for(log)
      {
        project_id: log.project_id,
        delivery_type: log.delivery_type,
        to_addresses: log.recipients.join(", "),
        subject: normalized_subject(log.subject)
      }
    end

    def normalized_subject(subject)
      subject.to_s.squish
    end
  end
end
