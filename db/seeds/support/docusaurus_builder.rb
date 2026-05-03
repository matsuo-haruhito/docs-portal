require "digest"
require "fileutils"
require "tmpdir"
require_relative "docusaurus_build_runner"
require_relative "docusaurus_diagram_page"
require_relative "docusaurus_markdown_normalizer"
require_relative "docusaurus_route_map"
require_relative "docusaurus_workspace_populator"

module SeedSupport
  module SeedDiagramFileExtnamePatch
    def extname(path)
      if SeedSupport::DocusaurusBuilder.seed_diagram_file_candidate?(path)
        ".md"
      else
        super
      end
    end
  end

  class DocusaurusBuilder
    MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze
    DIAGRAM_FILE_LANGUAGES = {
      ".puml" => "plantuml",
      ".plantuml" => "plantuml",
      ".d2" => "d2",
      ".mmd" => "mermaid",
      ".mermaid" => "mermaid"
    }.freeze
    KROKI_DIAGRAM_LANGUAGES = %w[plantuml d2].freeze
    LOCAL_ASSET_EXTENSIONS = %w[
      .png .jpg .jpeg .gif .webp .svg .bmp .ico .avif
    ].freeze
    DIAGRAM_FENCE_PATTERN = /\A\s{0,3}(```|~~~)\s*(plantuml|puml|d2)(?:\s|\z)/i

    def initialize(source_dir:, version:, site_build_path:)
      @source_dir = Pathname(source_dir)
      @version = version
      @site_build_path = site_build_path
    end

    def build
      return unless renderable_document_files?

      validate_kroki_endpoint!

      with_temp_workspace do |workspace|
        docs_src = workspace.join("docs-src")
        static_dir = workspace.join("static")
        build_output_dir = workspace.join("build")
        FileUtils.mkdir_p(static_dir)
        populate_docs_src!(docs_src)
        run_build!(docs_src, build_output_dir, static_dir)
        build_route_map
      end
    end

    def self.seed_doc_id_for(relative)
      digest = Digest::SHA1.hexdigest(relative.to_s)[0, 12]
      "seed-#{digest}"
    end

    def self.markdown_file?(path)
      MARKDOWN_EXTENSIONS.include?(Pathname(path).extname.downcase)
    end

    def self.diagram_file?(path)
      DIAGRAM_FILE_LANGUAGES.key?(Pathname(path).extname.downcase)
    end

    def self.diagram_language_for(path)
      DIAGRAM_FILE_LANGUAGES.fetch(Pathname(path).extname.downcase)
    end

    def self.renderable_document_file?(path)
      markdown_file?(path) || diagram_file?(path)
    end

    def self.install_seed_diagram_extname_patch!
      return if @seed_diagram_extname_patch_installed

      File.singleton_class.prepend(SeedDiagramFileExtnamePatch)
      @seed_diagram_extname_patch_installed = true
    end

    def self.seed_diagram_file_candidate?(path)
      value = path.to_s.tr("\\", "/")
      return false unless value.include?("/storage/document_files/external_samples/")

      diagram_file?(value)
    end

    private

    def renderable_document_files?
      Dir.glob(@source_dir.join("**/*").to_s).any? do |path|
        source = Pathname(path)
        source.file? && self.class.renderable_document_file?(source)
      end
    end

    def markdown_file?(path)
      self.class.markdown_file?(path)
    end

    def diagram_file?(path)
      self.class.diagram_file?(path)
    end

    def diagram_language_for(path)
      self.class.diagram_language_for(path)
    end

    def local_asset_file?(path)
      LOCAL_ASSET_EXTENSIONS.include?(path.extname.downcase)
    end

    def validate_kroki_endpoint!
      return if ENV["KROKI_ENDPOINT"].to_s.strip.present?

      diagram_files = files_requiring_kroki
      return if diagram_files.empty?

      message = [
        "KROKI_ENDPOINT is required because seed documents contain PlantUML/D2 diagrams.",
        "",
        "Set these values in .env when using the optional Kroki compose file:",
        "  COMPOSE_FILE=docker-compose.yml:docker-compose.kroki.yml",
        "  KROKI_ENDPOINT=http://kroki:8000",
        "",
        "Diagram files:",
        *diagram_files.first(10).map { |path| "  - #{path}" }
      ].join("\n")

      raise message
    end

    def files_requiring_kroki
      Dir.glob(@source_dir.join("**/*").to_s).sort.filter_map do |path|
        source = Pathname(path)
        next unless source.file?

        if markdown_file?(source)
          next unless markdown_contains_diagram?(source)
        elsif diagram_file?(source)
          next unless KROKI_DIAGRAM_LANGUAGES.include?(diagram_language_for(source))
        else
          next
        end

        source.relative_path_from(@source_dir).to_s
      end
    end

    def markdown_contains_diagram?(source)
      File.foreach(source).any? { |line| line.match?(DIAGRAM_FENCE_PATTERN) }
    end

    def with_temp_workspace
      Dir.mktmpdir("seed-docusaurus-") do |tmp_dir|
        yield Pathname(tmp_dir)
      end
    end

    def populate_docs_src!(docs_src)
      DocusaurusWorkspacePopulator.new(
        source_dir: @source_dir,
        docs_src:,
        site_build_path: @site_build_path,
        builder_class: self.class
      ).populate!
    end

    def run_build!(docs_src, build_output_dir, static_dir)
      DocusaurusBuildRunner.new(
        source_dir: @source_dir,
        version: @version,
        docs_src:,
        build_output_dir:,
        static_dir:
      ).run!
    end

    def build_route_map
      DocusaurusRouteMap.new(
        site_root_absolute_path: @version.site_root_absolute_path,
        site_build_path: @site_build_path
      ).build
    end
  end
end

if caller_locations.any? { _1.path.end_with?("/db/seeds.rb") }
  SeedSupport::DocusaurusBuilder.install_seed_diagram_extname_patch!
end
