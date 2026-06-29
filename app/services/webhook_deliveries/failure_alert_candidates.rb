module WebhookDeliveries
  class FailureAlertCandidates
    DEFAULT_THRESHOLD = 3
    DEFAULT_LIMIT = 20
    DEFAULT_LOOKBACK_LIMIT = 200

    Candidate = Data.define(
      :identity,
      :deliveries,
      :failure_count,
      :last_failed_at,
      :latest_error_message,
      :latest_response_status,
      :webhook_endpoint
    ) do
      def webhook_endpoint_id = identity.fetch(:webhook_endpoint_id)
      def event_type = identity.fetch(:event_type)
      def target_url_preview = identity.fetch(:target_url_preview)
      def latest_delivery = deliveries.first
    end

    def initialize(relation: WebhookDelivery.all, threshold: DEFAULT_THRESHOLD, limit: DEFAULT_LIMIT, lookback_limit: DEFAULT_LOOKBACK_LIMIT)
      @relation = relation
      @threshold = threshold
      @limit = limit
      @lookback_limit = lookback_limit
    end

    def call
      grouped_latest_deliveries.filter_map do |identity, deliveries|
        candidate_for(identity, deliveries)
      end.sort_by { |candidate| candidate.last_failed_at || Time.zone.at(0) }.reverse.first(limit)
    end

    private

    attr_reader :relation, :threshold, :limit, :lookback_limit

    def grouped_latest_deliveries
      ordered_deliveries.group_by do |delivery|
        identity_for(delivery)
      end
    end

    def ordered_deliveries
      scope = relation.includes(:webhook_endpoint).order(created_at: :desc, id: :desc)
      lookback_limit ? scope.limit(lookback_limit) : scope
    end

    def candidate_for(identity, deliveries)
      consecutive_failures = deliveries.take_while(&:failed?)
      return if consecutive_failures.size < threshold

      latest_failure = consecutive_failures.first
      Candidate.new(
        identity: identity,
        deliveries: consecutive_failures,
        failure_count: consecutive_failures.size,
        last_failed_at: latest_failure.sent_at || latest_failure.created_at,
        latest_error_message: latest_failure.error_message,
        latest_response_status: latest_failure.response_status,
        webhook_endpoint: latest_failure.webhook_endpoint
      )
    end

    def identity_for(delivery)
      {
        webhook_endpoint_id: delivery.webhook_endpoint_id,
        event_type: delivery.event_type,
        target_url_preview: WebhookDeliveryTargetUrlDisplay.new(delivery.target_url).to_s
      }
    end
  end
end
