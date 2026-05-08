module ApplicationConfiguration
  class SecretChecks
    def initialize(env:, rails_env:, check_builder:)
      @env = env
      @rails_env = rails_env
      @check_builder = check_builder
    end

    def call
      [
        secret_key_base_check,
        master_key_check,
        doc_import_token_check
      ]
    end

    private

    attr_reader :env, :rails_env, :check_builder

    def secret_key_base_check
      key = "SECRET_KEY_BASE"
      value = env[key]

      return check_builder.error(key, "SECRET_KEY_BASE is missing", "署名や暗号化に使うため、必ず設定してください。") if blank?(value)

      if production? && value == "secret"
        check_builder.error(key, "SECRET_KEY_BASE uses the development sample value", "本番では .env.example のサンプル値を使わず、十分に長い秘密値を設定してください。")
      elsif value.length < 30
        check_builder.warning(key, "SECRET_KEY_BASE is short", "開発環境以外では、十分に長い秘密値を使うことを推奨します。")
      else
        check_builder.ok(key, "SECRET_KEY_BASE is set", "秘密値が設定されています。")
      end
    end

    def master_key_check
      key = "RAILS_MASTER_KEY"
      value = env[key]

      return check_builder.warning(key, "RAILS_MASTER_KEY is missing", "credentials を使う環境では設定してください。") if blank?(value)

      if production? && value == "replace_me"
        check_builder.error(key, "RAILS_MASTER_KEY uses the sample value", "本番では .env.example のサンプル値を使わないでください。")
      elsif value == "replace_me"
        check_builder.warning(key, "RAILS_MASTER_KEY uses the sample value", "credentials を使う場合は実値に置き換えてください。")
      else
        check_builder.ok(key, "RAILS_MASTER_KEY is set", "master key が設定されています。")
      end
    end

    def doc_import_token_check
      key = "DOC_IMPORT_TOKEN"
      value = env[key]

      return check_builder.error(key, "DOC_IMPORT_TOKEN is missing", "内部import APIを使うため、トークンを設定してください。") if blank?(value)

      if production? && value == "local-dev-import-token"
        check_builder.error(key, "DOC_IMPORT_TOKEN uses the development sample value", "本番では開発用サンプルトークンを使わないでください。")
      elsif value == "local-dev-import-token"
        check_builder.warning(key, "DOC_IMPORT_TOKEN uses the development sample value", "開発環境以外へ流用しないでください。")
      else
        check_builder.ok(key, "DOC_IMPORT_TOKEN is set", "内部import API用トークンが設定されています。")
      end
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def production?
      rails_env.production?
    end
  end
end
