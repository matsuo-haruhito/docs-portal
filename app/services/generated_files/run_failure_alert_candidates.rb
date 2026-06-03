module GeneratedFiles
  class RunFailureAlertCandidates
    DEFAULT_THRESHOLD = 3
    DEFAULT_LIMIT = 20

    Candidate = Data.define(
      :identity,
      :runs,
      :failure_count,
      :last_failed_at,
      :latest_error_message
    ) do
      def job_id = identity.fetch(:job_id)
      def generator = identity[:generator]
      def output_writer = identity[:output_writer]
      def event_source = identity[:event_source]
    end

    def initialize(relation: GeneratedFileRun.all, threshold: DEFAULT_THRESHOLD, limit: DEFAULT_LIMIT)
      @relation = relation
      @threshold = threshold
      @limit = limit
    end

    def call
      grouped_latest_runs.filter_map do |identity, runs|
        candidate_for(identity, runs)
      end.sort_by { |candidate| candidate.last_failed_at || Time.zone.at(0) }.reverse.first(@limit)
    end

    private

    attr_reader :relation, :threshold, :limit

    def grouped_latest_runs
      relation.order(started_at: :desc, created_at: :desc, id: :desc).group_by do |run|
        identity_for(run)
      end
    end

    def candidate_for(identity, runs)
      consecutive_failures = runs.take_while(&:failed?)
      return if consecutive_failures.size < threshold

      latest_failure = consecutive_failures.first
      Candidate.new(
        identity: identity,
        runs: consecutive_failures,
        failure_count: consecutive_failures.size,
        last_failed_at: latest_failure.finished_at || latest_failure.started_at || latest_failure.created_at,
        latest_error_message: latest_failure.error_message
      )
    end

    def identity_for(run)
      {
        job_id: run.job_id,
        generator: run.generator,
        output_writer: run.output_writer,
        event_source: run.event_source
      }
    end
  end
end
