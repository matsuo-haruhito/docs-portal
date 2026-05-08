module GitImport
  class PathCatalog
    MARKDOWN_EXTENSIONS = %w[.md .mdx].freeze
    DIAGRAM_EXTENSIONS = %w[.mmd .mermaid .puml .plantuml .d2].freeze

    def initialize(worktree_path:)
      @worktree_path = Pathname(worktree_path)
    end

    def markdown_paths
      Dir.glob(worktree_path.join("**", "*").to_s).map { Pathname.new(_1) }.select do |path|
        path.file? && MARKDOWN_EXTENSIONS.include?(path.extname.downcase)
      end.sort
    end

    def attachment_paths_for(markdown_path)
      sibling_files = markdown_path.dirname.children.select(&:file?)
      sibling_files.reject do |path|
        path == markdown_path || MARKDOWN_EXTENSIONS.include?(path.extname.downcase)
      end.select do |path|
        DIAGRAM_EXTENSIONS.include?(path.extname.downcase) || !path.basename.to_s.start_with?(".")
      end.sort
    end

    def content_type_for(path)
      case path.extname.downcase
      when ".md", ".mdx"
        "text/markdown"
      when ".png"
        "image/png"
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".gif"
        "image/gif"
      when ".svg"
        "image/svg+xml"
      when ".pdf"
        "application/pdf"
      else
        "application/octet-stream"
      end
    end

    private

    attr_reader :worktree_path
  end
end
