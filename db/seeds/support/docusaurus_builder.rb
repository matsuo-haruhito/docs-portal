require "fileutils"
require "open3"
require "tmpdir"

module SeedSupport
  class DocusaurusBuilder
    BUILD_ROOT = Rails.root.join("docusaurus")

    def initialize(source_dir:, version:, site_build_path:)
      @source_dir = Pathname(source_dir)
      @version = version
      @site_build_path = site_build_path
    end

    def call
      return unless markdown_files?

      with_temp_workspace do |workspace|
        docs_src = workspace.join("docs-src")
        build_output_dir = workspace.join("build")
        populate_docs_src!(docs_src)
        run_build!(docs_src, build_output_dir)
        copy_build!(build_output_dir)
      end
    end

    private

    def markdown_files?
      Dir.glob(@source_dir.join("**/*").to_s).any? do |path|
        next false unless File.file?(path)

        %w[.md .markdown].include?(File.extname(path).downcase)
      end
    end

    def with_temp_workspace
      Dir.mktmpdir("seed-docusaurus-") do |tmp_dir|
        yield Pathname(tmp_dir)
      end
    end

    def populate_docs_src!(docs_src)
      root = docs_src.join(@site_build_path)
      FileUtils.mkdir_p(root)

      Dir.glob(@source_dir.join("**/*").to_s).sort.each do |path|
        source = Pathname(path)
        next unless source.file?
        next unless %w[.md .markdown].include?(source.extname.downcase)

        relative = source.relative_path_from(@source_dir)
        destination = root.join(normalized_doc_relative_path(relative))
        FileUtils.mkdir_p(destination.dirname)
        FileUtils.cp(source, destination)
      end
    end

    def normalized_doc_relative_path(relative)
      basename = relative.basename.to_s
      normalized_basename =
        if basename.match?(/\AREADME\.(md|markdown)\z/i)
          "index.md"
        else
          basename
        end

      relative.dirname.join(normalized_basename)
    end

    def run_build!(docs_src, build_output_dir)
      env = {
        "DOCUSAURUS_DOCS_PATH" => docs_src.to_s
      }

      stdout, stderr, status = Open3.capture3(
        env,
        "npm", "run", "build", "--", "--out-dir", build_output_dir.to_s,
        chdir: BUILD_ROOT.to_s
      )

      return if status.success?

      raise "Docusaurus build failed for #{@source_dir}: #{stderr.presence || stdout}"
    end

    def copy_build!(build_output_dir)
      destination = @version.site_root_absolute_path
      FileUtils.mkdir_p(destination)
      FileUtils.rm_rf(destination.children)
      FileUtils.cp_r(build_output_dir.children, destination)

      return if @version.site_entry_absolute_path&.exist?

      raise "Seed Docusaurus build output missing entry path: #{@site_build_path}"
    end
  end
end
