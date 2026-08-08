module ApplicationConfiguration
  class EnvironmentChecks
    def initialize(env:, check_builder:)
      @env = env
      @check_builder = check_builder
    end

    def call
      [
        *required_env_checks,
        *numeric_env_checks,
        *boolean_env_checks
      ]
    end

    private

    attr_reader :env, :check_builder

    def required_env_checks
      ApplicationConfigurationDiagnostic::REQUIRED_ENV_KEYS.map do |key|
        if present_env?(key)
          check_builder.ok(key, "#{key} is set", "必須環境変数が設定されています。")
        else
          check_builder.error(key, "#{key} is missing", "必須環境変数が未設定です。 .env.example を基準に設定してください。")
        end
      end
    end

    def numeric_env_checks
      ApplicationConfigurationDiagnostic::NUMERIC_ENV_KEYS.filter_map do |key|
        next unless present_env?(key)

        if integer_string?(env[key])
          check_builder.ok(key, "#{key} is numeric", "数値として解釈できます。", env[key])
        else
          check_builder.error(key, "#{key} must be numeric", "ポート番号やスレッド数として扱うため、整数で設定してください。", env[key])
        end
      end
    end

    def boolean_env_checks
      ApplicationConfigurationDiagnostic::BOOLEAN_ENV_KEYS.map do |key|
        value = env[key]
        if blank?(value)
          check_builder.warning(key, "#{key} is not set", "未設定時はfalseとして扱います。consumer-first rolloutで有効化するまでfalseを明示してください。")
        elsif %w[true false].include?(value.to_s.strip.downcase)
          check_builder.ok(key, "#{key} is boolean", "trueまたはfalseとして解釈できます。", value.to_s.strip.downcase)
        else
          check_builder.error(key, "#{key} must be true or false", "rolling deployの切替に使うため、trueまたはfalseを設定してください。", value)
        end
      end
    end

    def present_env?(key)
      !blank?(env[key])
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def integer_string?(value)
      value.to_s.match?(/\A\d+\z/)
    end
  end
end
