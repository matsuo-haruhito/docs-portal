module ApplicationConfiguration
  class WorkspaceChecks
    def initialize(env:, root:, check_builder:)
      @env = env
      @root = Pathname(root)
      @check_builder = check_builder
    end

    def call
      [
        docusaurus_workspace_check,
        kroki_endpoint_check
      ]
    end

    private

    attr_reader :env, :root, :check_builder

    def docusaurus_workspace_check
      path = root.join("docusaurus")
      package_json = path.join("package.json")

      return check_builder.error("docusaurus.workspace", "docusaurus directory is missing", "Docusaurus build に必要なディレクトリが見つかりません。", path.to_s) unless path.directory?
      return check_builder.error("docusaurus.package", "docusaurus/package.json is missing", "Docusaurus build に必要な package.json が見つかりません。", package_json.to_s) unless package_json.file?

      check_builder.ok("docusaurus.workspace", "Docusaurus workspace is present", "Docusaurus build 用の作業ディレクトリがあります。", path.to_s)
    end

    def kroki_endpoint_check
      key = "KROKI_ENDPOINT"
      value = env[key]
      compose_file = env["COMPOSE_FILE"].to_s

      return check_builder.ok(key, "KROKI_ENDPOINT is set", "PlantUML / D2 のレンダリング先が設定されています。", value) if present_env?(key)

      if compose_file.include?("docker-compose.kroki.yml")
        check_builder.error(key, "KROKI_ENDPOINT is missing while Kroki compose is enabled", "docker-compose.kroki.yml を使う場合は KROKI_ENDPOINT=http://kroki:8000 を設定してください。")
      else
        check_builder.warning(key, "KROKI_ENDPOINT is not set", "PlantUML / D2 をレンダリングする場合は Kroki endpoint を設定してください。")
      end
    end

    def present_env?(key)
      !blank?(env[key])
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
