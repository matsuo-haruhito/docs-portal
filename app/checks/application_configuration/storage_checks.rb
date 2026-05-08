module ApplicationConfiguration
  class StorageChecks
    def initialize(env:, root:, check_builder:)
      @env = env
      @root = Pathname(root)
      @check_builder = check_builder
    end

    def call
      [
        active_storage_service_check,
        storage_root_check
      ]
    end

    private

    attr_reader :env, :root, :check_builder

    def active_storage_service_check
      key = "ACTIVE_STORAGE_SERVICE"
      service = env[key]
      storage_config_path = root.join("config", "storage.yml")

      return check_builder.error(key, "ACTIVE_STORAGE_SERVICE is missing", "Active Storage の利用サービスを設定してください。") if blank?(service)
      return check_builder.error(key, "config/storage.yml is missing", "storage設定ファイルが見つかりません。", storage_config_path.to_s) unless storage_config_path.file?

      storage_config = storage_config_path.read

      if storage_config.match?(/^#{Regexp.escape(service)}:/)
        check_builder.ok(key, "ACTIVE_STORAGE_SERVICE is defined", "storage.yml に定義済みのサービスです。", service)
      else
        check_builder.error(key, "ACTIVE_STORAGE_SERVICE is not defined in storage.yml", "storage.yml に存在するサービス名を指定してください。", service)
      end
    end

    def storage_root_check
      path = root.join("storage", "document_files")

      if path.directory?
        writable_path_check("document_files storage root", path)
      elsif path.dirname.directory? && path.dirname.writable?
        check_builder.warning("storage.document_files", "document_files storage root does not exist yet", "必要時に作成可能な状態です。", path.to_s)
      else
        check_builder.error("storage.document_files", "document_files storage root is not available", "storage/document_files を作成できる権限が必要です。", path.to_s)
      end
    end

    def writable_path_check(key, path)
      if path.writable?
        check_builder.ok(key, "#{path} is writable", "ファイル保存先に書き込みできます。", path.to_s)
      else
        check_builder.error(key, "#{path} is not writable", "ファイル保存先に書き込み権限がありません。", path.to_s)
      end
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
