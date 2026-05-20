class DocumentVersionPreviewTargetMetadata
  METADATA_FILE_NAMES = %w[
    .docs-portal-preview.yml
    .docs-portal-preview.yaml
    .preview-targets.yml
    .preview-targets.yaml
    preview-targets.yml
    preview-targets.yaml
    preview_targets.yml
    preview_targets.yaml
  ].freeze

  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze

  Result = Data.define(:source_file, :metadata, :warnings) do
    def source_file?
      source_file.present?
    end

    def valid?
      warnings.empty?
    end

    def paths_for(key)
      Array(metadata[key.to_s])
    end
  end

  def initialize(document_version)
    @document_version = document_version
  end

  def call
    source_file = metadata_source_file
    return Result.new(source_file: nil, metadata: {}, warnings: []) unless source_file

    parsed = DocumentFilePreviewTargetMetadata.new(
      source: read_source(source_file),
      document_files: document_files
    ).call

    Result.new(source_file:, metadata: parsed.metadata, warnings: parsed.warnings)
  end

  private

  attr_reader :document_version

  def metadata_source_file
    explicit_metadata_file || markdown_source_file
  end

  def explicit_metadata_file
    document_files.detect do |file|
      METADATA_FILE_NAMES.include?(File.basename(file.tree_path.to_s))
    end
  end

  def markdown_source_file
    document_files.detect do |file|
      MARKDOWN_EXTENSIONS.include?(File.extname(file.tree_path.to_s).downcase)
    end
  end

  def document_files
    @document_files ||= document_version.document_files.order(:sort_order, :id).to_a
  end

  def read_source(file)
    File.read(file.absolute_path, encoding: "UTF-8")
  rescue Errno::ENOENT, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    "preview_targets:\n  invalid_source: #{e.message.inspect}\n"
  end
end
