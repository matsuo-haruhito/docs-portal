require "open3"

module SeedSupport
  class DocusaurusRuntimeChecker
    BUILD_ROOT = Rails.root.join("docusaurus")
    LOCAL_CLI_PATH = BUILD_ROOT.join("node_modules/.bin/docusaurus")
    INSTALL_COMMAND = %w[npm ci --no-fund --no-audit].freeze
    NPM_MESSAGE = "Docusaurus build requires npm. Please prepare Node.js and npm before running the build."

    def self.ensure_runtime!
      new.ensure_runtime!
    end

    def self.ensure_npm!
      new.ensure_npm!
    end

    def ensure_runtime!
      ensure_npm!
      ensure_local_cli!
    end

    def ensure_npm!
      _stdout, _stderr, status = Open3.capture3("npm", "--version")
      return true if status.success?

      raise NPM_MESSAGE
    rescue Errno::ENOENT
      raise NPM_MESSAGE
    end

    private

    def ensure_local_cli!
      return true if LOCAL_CLI_PATH.exist?

      stdout, stderr, status = Open3.capture3(*INSTALL_COMMAND, chdir: BUILD_ROOT.to_s)
      return true if status.success? && LOCAL_CLI_PATH.exist?

      message = stderr.to_s.strip
      message = stdout.to_s.strip if message.empty?
      raise <<~MESSAGE
        Docusaurus build requires repo-local npm dependencies under #{BUILD_ROOT}.
        Tried `#{INSTALL_COMMAND.join(" ")}` before building but it did not prepare the Docusaurus CLI.
        #{message}
      MESSAGE
    end
  end
end
