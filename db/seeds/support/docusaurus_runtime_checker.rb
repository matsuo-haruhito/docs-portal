require "open3"

module SeedSupport
  class DocusaurusRuntimeChecker
    MESSAGE = "Docusaurus build requires npm. Please prepare Node.js and npm before running the build."

    def self.ensure_npm!
      new.ensure_npm!
    end

    def ensure_npm!
      _stdout, _stderr, status = Open3.capture3("npm", "--version")
      return true if status.success?

      raise MESSAGE
    rescue Errno::ENOENT
      raise MESSAGE
    end
  end
end
