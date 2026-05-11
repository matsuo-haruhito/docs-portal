class ApplicationConfigurationDiagnostic
  Check = Data.define(:key, :label, :status, :message, :detail) do
    def ok?
      status == :ok
    end

    def warning?
      status == :warning
    end

    def error?
      status == :error
    end
  end

  Result = Data.define(:checks) do
    def ok_count
      checks.count(&:ok?)
    end

    def warning_count
      checks.count(&:warning?)
    end

    def error_count
      checks.count(&:error?)
    end

    def healthy?
      error_count.zero?
    end
  end

  REQUIRED_ENV_KEYS = %w[
    DATABASE_HOST
    DATABASE_PORT
    DATABASE_USER
    DATABASE_NAME
    DATABASE_PASSWORD
    ACTIVE_STORAGE_SERVICE
    PUBLISH_WEB_SERVER_PORT
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  ].freeze

  NUMERIC_ENV_KEYS = %w[
    DATABASE_PORT
    PUBLISH_WEB_SERVER_PORT
    RAILS_MAX_THREADS
  ].freeze

  def initialize(env: ENV, root: Rails.root, rails_env: Rails.env)
    @env = env
    @root = Pathname(root)
    @rails_env = rails_env
  end

  def call
    check_builder = ApplicationConfiguration::CheckBuilder.new(check_class: Check)

    Result.new(checks: [
      *ApplicationConfiguration::EnvironmentChecks.new(env:, check_builder:).call,
      *ApplicationConfiguration::SecretChecks.new(env:, rails_env:, check_builder:).call,
      *ApplicationConfiguration::StorageChecks.new(env:, root:, check_builder:).call,
      *ApplicationConfiguration::WorkspaceChecks.new(env:, root:, check_builder:).call
    ])
  end

  private

  attr_reader :env, :root, :rails_env
end
