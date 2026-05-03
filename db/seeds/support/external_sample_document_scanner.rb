require "digest"
require_relative "docusaurus_builder"

module SeedSupport
  class ExternalSampleDocumentScanner
    VERSION_SNAPSHOT_DIRECTORY_NAMES = %w[
      編集正本
      編集正本PDF化済
      編集正本PDF化
      提出済
      提出済み
    ].freeze

    def initialize(root:)
      @root = Pathname(root) if root
    end

    def document_files_for(source_root, excluded_roots: [])
      Dir.glob(source_root.join("**/*").to_s).select do |path|
        next false unless File.file?(path)
        next false unless DocusaurusBuilder.renderable_document_file?(path)

        excluded_roots.none? { Pathname(path).to_s.start_with?(_1.to_s + File::SEPARATOR) }
      end.sort
    end

    def related_attachment_files(document_file, logical_relative_path, source_root)
      path = Pathname(logical_relative_path.to_s)
      source_path = Pathname(document_file)

      Dir.glob(source_path.dirname.join("#{path.basename.sub_ext('').to_s}.*").to_s)
        .select { File.file?(_1) }
        .reject { Pathname(_1) == source_path && !DocusaurusBuilder.diagram_file?(_1) }
        .sort
    end

    def content_type_for(path)
      extension = File.extname(path).downcase
      return "text/markdown" if DocusaurusBuilder.markdown_file?(path)
      return "text/plain" if DocusaurusBuilder.diagram_file?(path)

      Rack::Mime.mime_type(extension, "application/octet-stream")
    end

    def sample_root?
      @root&.directory?
    end

    private

    def child_directories(path)
      path.children.select(&:directory?).sort_by(&:to_s)
    end

    def version_snapshot_directory?(path)
      VERSION_SNAPSHOT_DIRECTORY_NAMES.include?(path.basename.to_s)
    end
  end
end
