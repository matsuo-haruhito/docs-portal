module ZipImport
  class PathClassifier
    MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze
    DIAGRAM_EXTENSIONS = %w[.puml .plantuml .d2 .mmd .mermaid].freeze
    HTML_EXTENSIONS = %w[.html .htm].freeze
    IGNORED_BASENAMES = %w[.ds_store thumbs.db].freeze

    def initialize(root:)
      @root = Pathname(root)
    end

    def markdown_file?(path)
      MARKDOWN_EXTENSIONS.include?(Pathname(path).extname.downcase)
    end

    def diagram_file?(path)
      DIAGRAM_EXTENSIONS.include?(Pathname(path).extname.downcase)
    end

    def html_file?(path)
      HTML_EXTENSIONS.include?(Pathname(path).extname.downcase)
    end

    def renderable_document_file?(path)
      markdown_file?(path) || diagram_file?(path)
    end

    def static_html_document_file?(path)
      html_file?(path)
    end

    def attachment_owner_candidate_file?(path)
      renderable_document_file?(path) || static_html_document_file?(path)
    end

    def document_candidate_file?(path)
      !ignored_file?(path)
    end

    def content_type_for(path)
      return "text/markdown" if markdown_file?(path)
      return "text/plain" if diagram_file?(path)

      Rack::Mime.mime_type(Pathname(path).extname.downcase, "application/octet-stream")
    end

    def logical_path_for(path)
      Pathname(path).relative_path_from(root).to_s.tr("\\", "/")
    end

    def ignored_file?(path)
      logical_path = logical_path_for(path)
      basename = File.basename(logical_path).downcase
      return true if IGNORED_BASENAMES.include?(basename)
      return true if basename.start_with?("._")

      logical_path.split("/").any? { |segment| segment.casecmp("__MACOSX").zero? }
    end

    private

    attr_reader :root
  end
end
