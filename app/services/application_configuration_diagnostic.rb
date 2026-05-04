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
    Result.new(checks: [
      *required_env_checks,
      *numeric_env_checks,
      secret_key_base_check,
      master_key_check,
      doc_import_token_check,
      active_storage_service_check,
      storage_root_check,
      docusaurus_workspace_check,
      kroki_endpoint_check
    ])
  end

  private

  attr_reader :env, :root, :rails_env

  def required_env_checks
    REQUIRED_ENV_KEYS.map do |key|
      if present_env?(key)
        ok(key, "#{key} is set", "必須環境変数が設定されています。")
      else
        error(key, "#{key} is missing", "必須環境変数が未設定です。 .env.example を基準に設定してください。")
      end
    end
  end

  def numeric_env_checks
    NUMERIC_ENV_KEYS.filter_map do |key|
      next unless present_env?(key)

      if integer_string?(env[key])
        ok(key, "#{key} is numeric", "数値として解釈できます。", env[key])
      else
        error(key, "#{key} must be numeric", "ポート番号やスレッド数として扱うため、整数で設定してください。", env[key])
      end
    end
  end

  def secret_key_base_check
    key = "SECRET_KEY_BASE"
    value = env[key]

    return error(key, "SECRET_KEY_BASE is missing", "署名や暗号化に使うため、必ず設定してください。") if blank?(value)

    if production? && value == "secret"
      error(key, "SECRET_KEY_BASE uses the development sample value", "本番では .env.example のサンプル値を使わず、十分に長い秘密値を設定してください。")
    elsif value.length < 30
      warning(key, "SECRET_KEY_BASE is short", "開発環境以外では、十分に長い秘密値を使うことを推奨します。")
    else
      ok(key, "SECRET_KEY_BASE is set", "秘密値が設定されています。")
    end
  end

  def master_key_check
    key = "RAILS_MASTER_KEY"
    value = env[key]

    return warning(key, "RAILS_MASTER_KEY is missing", "credentials を使う環境では設定してください。") if blank?(value)

    if production? && value == "replace_me"
      error(key, "RAILS_MASTER_KEY uses the sample value", "本番では .env.example のサンプル値を使わないでください。")
    elsif value == "replace_me"
      warning(key, "RAILS_MASTER_KEY uses the sample value", "credentials を使う場合は実値に置き換えてください。")
    else
      ok(key, "RAILS_MASTER_KEY is set", "master key が設定されています。")
    end
  end

  def doc_import_token_check
    key = "DOC_IMPORT_TOKEN"
    value = env[key]

    return error(key, "DOC_IMPORT_TOKEN is missing", "内部import APIを使うため、トークンを設定してください。") if blank?(value)

    if production? && value == "local-dev-import-token"
      error(key, "DOC_IMPORT_TOKEN uses the development sample value", "本番では開発用サンプルトークンを使わないでください。")
    elsif value == "local-dev-import-token"
      warning(key, "DOC_IMPORT_TOKEN uses the development sample value", "開発環境以外へ流用しないでください。")
    else
      ok(key, "DOC_IMPORT_TOKEN is set", "内部import API用トークンが設定されています。")
    end
  end

  def active_storage_service_check
    key = "ACTIVE_STORAGE_SERVICE"
    service = env[key]
    storage_config_path = root.join("config", "storage.yml")

    return error(key, "ACTIVE_STORAGE_SERVICE is missing", "Active Storage の利用サービスを設定してください。") if blank?(service)
    return error(key, "config/storage.yml is missing", "storage設定ファイルが見つかりません。", storage_config_path.to_s) unless storage_config_path.file?

    storage_config = storage_config_path.read

    if storage_config.match?(/^#{Regexp.escape(service)}:/)
      ok(key, "ACTIVE_STORAGE_SERVICE is defined", "storage.yml に定義済みのサービスです。", service)
    else
      error(key, "ACTIVE_STORAGE_SERVICE is not defined in storage.yml", "storage.yml に存在するサービス名を指定してください。", service)
    end
  end

  def storage_root_check
    path = root.join("storage", "document_files")

    if path.directory?
      writable_path_check("document_files storage root", path)
    elsif path.dirname.directory? && path.dirname.writable?
      warning("storage.document_files", "document_files storage root does not exist yet", "必要時に作成可能な状態です。", path.to_s)
    else
      error("storage.document_files", "document_files storage root is not available", "storage/document_files を作成できる権限が必要です。", path.to_s)
    end
  end

  def docusaurus_workspace_check
    path = root.join("docusaurus")
    package_json = path.join("package.json")

    return error("docusaurus.workspace", "docusaurus directory is missing", "Docusaurus build に必要なディレクトリが見つかりません。", path.to_s) unless path.directory?
    return error("docusaurus.package", "docusaurus/package.json is missing", "Docusaurus build に必要な package.json が見つかりません。", package_json.to_s) unless package_json.file?

    ok("docusaurus.workspace", "Docusaurus workspace is present", "Docusaurus build 用の作業ディレクトリがあります。", path.to_s)
  end

  def kroki_endpoint_check
    key = "KROKI_ENDPOINT"
    value = env[key]
    compose_file = env["COMPOSE_FILE"].to_s

    return ok(key, "KROKI_ENDPOINT is set", "PlantUML / D2 のレンダリング先が設定されています。", value) if present_env?(key)

    if compose_file.include?("docker-compose.kroki.yml")
      error(key, "KROKI_ENDPOINT is missing while Kroki compose is enabled", "docker-compose.kroki.yml を使う場合は KROKI_ENDPOINT=http://kroki:8000 を設定してください。")
    else
      warning(key, "KROKI_ENDPOINT is not set", "PlantUML / D2 をレンダリングする場合は Kroki endpoint を設定してください。")
    end
  end

  def writable_path_check(key, path)
    if path.writable?
      ok(key, "#{path} is writable", "ファイル保存先に書き込みできます。", path.to_s)
    else
      error(key, "#{path} is not writable", "ファイル保存先に書き込み権限がありません。", path.to_s)
    end
  end

  def ok(key, label, message, detail = nil)
    Check.new(key:, label:, status: :ok, message:, detail:)
  end

  def warning(key, label, message, detail = nil)
    Check.new(key:, label:, status: :warning, message:, detail:)
  end

  def error(key, label, message, detail = nil)
    Check.new(key:, label:, status: :error, message:, detail:)
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

  def production?
    rails_env.production?
  end
end
