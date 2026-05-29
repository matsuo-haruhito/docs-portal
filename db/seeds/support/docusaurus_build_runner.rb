require "fileutils"
require "open3"
require_relative "docusaurus_runtime_checker"

module SeedSupport
  class DocusaurusBuildRunner
    BUILD_ROOT = Rails.root.join("docusaurus")

    def initialize(source_dir:, version:, docs_src:, build_output_dir:, static_dir: nil)
      @source_dir = source_dir
      @version = version
      @docs_src = docs_src
      @build_output_dir = build_output_dir
      @static_dir = static_dir
    end

    def run!
      DocusaurusRuntimeChecker.ensure_runtime!
      run_build!
      copy_build!
    end

    private

    def run_build!
      env = {
        "DOCUSAURUS_DOCS_PATH" => @docs_src.to_s
      }
      env["DOCUSAURUS_STATIC_DIR"] = @static_dir.to_s if @static_dir

      stdout, stderr, status = Open3.capture3(
        env,
        "npm", "run", "build", "--", "--out-dir", @build_output_dir.to_s,
        chdir: BUILD_ROOT.to_s
      )

      return if status.success?

      raise build_failure_message(stdout:, stderr:)
    end

    def build_failure_message(stdout:, stderr:)
      [
        "Docusaurus build failed",
        "source_dir: #{@source_dir}",
        "docs_path: #{@docs_src}",
        "out_dir: #{@build_output_dir}",
        ("static_dir: #{@static_dir}" if @static_dir),
        "command: npm run build -- --out-dir #{@build_output_dir}",
        "output:",
        build_output_message(stdout:, stderr:)
      ].compact.join("\n")
    end

    def build_output_message(stdout:, stderr:)
      sections = []
      sections << "stderr:\n#{stderr}" if stderr.present?
      sections << "stdout:\n#{stdout}" if stdout.present?

      sections.presence&.join("\n\n") || "(no stdout or stderr)"
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
