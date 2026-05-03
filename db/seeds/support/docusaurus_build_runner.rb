require "fileutils"
require "open3"

module SeedSupport
  class DocusaurusBuildRunner
    BUILD_ROOT = Rails.root.join("docusaurus")

    def initialize(source_dir:, version:, docs_src:, build_output_dir:)
      @source_dir = source_dir
      @version = version
      @docs_src = docs_src
      @build_output_dir = build_output_dir
    end

    def run!
      run_build!
      copy_build!
    end

    private

    def run_build!
      env = {
        "DOCUSAURUS_DOCS_PATH" => @docs_src.to_s
      }

      stdout, stderr, status = Open3.capture3(
        env,
        "npm", "run", "build", "--", "--out-dir", @build_output_dir.to_s,
        chdir: BUILD_ROOT.to_s
      )

      return if status.success?

      raise "Docusaurus build failed for #{@source_dir}: #{stderr.presence || stdout}"
    end

    def copy_build!
      destination = @version.site_root_absolute_path
      FileUtils.mkdir_p(destination)
      FileUtils.rm_rf(destination.children)
      FileUtils.cp_r(@build_output_dir.children, destination)

      return if @version.site_entry_absolute_path&.exist?

      raise "Seed Docusaurus build output missing entry path: #{@version.site_build_path}"
    end
  end
end
