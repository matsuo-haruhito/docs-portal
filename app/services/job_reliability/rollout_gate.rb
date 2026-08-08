module JobReliability
  class RolloutGate
    ENV_KEY = "JOB_RELIABILITY_V2_ENABLED"

    class << self
      def enabled?(env: ENV)
        env.fetch(ENV_KEY, nil).to_s.strip.casecmp?("true")
      end
    end
  end
end
