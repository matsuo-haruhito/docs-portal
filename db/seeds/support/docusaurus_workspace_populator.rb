require "fileutils"
require_relative "docusaurus_diagram_page"
require_relative "docusaurus_markdown_normalizer"

module SeedSupport
  class DocusaurusWorkspacePopulator
    def initialize(source_dir:, docs_src:, site_build_path:, builder_class: DocusaurusBuilder)
      @source_dir = Pathname(source_dir)
      @docs_src = Pathname(docs_src)
      @site_build_path = site_build_path
      @builder_class = builder_class
    end

    def populate!
      FileUtils.mkdir_p(root)

      Dir.glob(@source_dir.join("**/*").to_s).sort.each do |path|
        source = Pathname(path)
        next unless source.file?

        relative = source.relative_path_from(@source_dir)
        copy_or_render(source, relative)
      end
    end

    private

    def root
      @docs_src.join(@site_build_path)
    end

    def copy_or_render(source, relative)
      if @builder_class.markdown_file?(source)
        write_markdown(source, relative)
      elsif @builder_class.diagram_file?(source)
        write_diagram(source, relative)
      elsif local_asset_file?(source)
        copy_asset(source, relative)
      end
    end

    def write_markdown(source, relative)
      destination = root.join(normalized_doc_relative_path(relative))
      FileUtils.mkdir_p(destination.dirname)
      destination.write(
        DocusaurusMarkdownNormalizer.new(
          markdown: File.read(source),
          generated_id: seed_doc_id(relative)
        ).normalize
      )
    end

    def write_diagram(source, relative)
      destination = root.join(normalized_doc_relative_path(relative))
      FileUtils.mkdir_p(destination.dirname)
      destination.write(
        DocusaurusDiagramPage.new(
          source:,
          relative:,
          language: @builder_class.diagram_language_for(source),
          generated_id: seed_doc_id(relative)
        ).markdown
      )
    end

    def copy_asset(source, relative)
      destination = root.join(relative)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(source, destination)
    end

    def local_asset_file?(path)
      @builder_class::LOCAL_ASSET_EXTENSIONS.include?(path.extname.downcase)
    end

    def seed_doc_id(relative)
      @builder_class.seed_doc_id_for(relative)
    end

    def normalized_doc_relative_path(relative)
      basename = relative.basename.to_s
      normalized_basename =
        if basename.match?(/\AREADME\.(md|markdown)\z/i)
          "index.md"
        elsif @builder_class.diagram_file?(relative)
          "#{relative.basename.sub_ext("")}.md"
        else
          basename
        end

      relative.dirname.join(normalized_basename)
    end
  end
end
