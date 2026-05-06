class ZipImportDocumentScanner
  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze
  DIAGRAM_EXTENSIONS = %w[.puml .plantuml .d2 .mmd .mermaid].freeze
  DOCUMENT_EXTENSIONS = (MARKDOWN_EXTENSIONS + DIAGRAM_EXTENSIONS).freeze
  README_BASENAMES = %w[readme index].freeze
  IGNORED_BASENAMES = %w[.ds_store thumbs.db].freeze
  LINK_PATTERN = /
    !?\[[^\]]*\]
    \(
      \s*
      (?<target>[^)\s]+(?:\s+[^)])*?)
      \s*
    \)
  /x.freeze

  DocumentCandidate = Data.define(
    :absolute_path,
    :logical_path,
    :title,
    :slug,
    :frontmatter,
    :document_kind,
    :attachment_paths,
    :warnings
  )

  ScanResult = Data.define(:documents, :orphan_files, :skipped_files, :warnings)

  def initialize(root:)
    @root = Pathname(root)
  end

  def call
    document_files = all_files.select { document_candidate_file?(_1) }
    documents = document_files.map { build_document_candidate(_1) }
    attached_paths = documents.flat_map(&:attachment_paths).uniq
    remaining_files = all_files.reject { attached_paths.include?(_1) || document_files.include?(_1) }
    orphan_files = remaining_files.reject { ignored_file?(_1) }.map { logical_path_for(_1) }
    skipped_files = remaining_files.select { ignored_file?(_1) }.map { logical_path_for(_1) }

    ScanResult.new(
      documents:,
      orphan_files: orphan_files.sort,
      skipped_files: skipped_files.sort,
      warnings: documents.flat_map(&:warnings)
    )
  end

  def markdown_file?(path)
    MARKDOWN_EXTENSIONS.include?(Pathname(path).extname.downcase)
  end

  def diagram_file?(path)
    DIAGRAM_EXTENSIONS.include?(Pathname(path).extname.downcase)
  end

  def content_type_for(path)
    return "text/markdown" if markdown_file?(path)
    return "text/plain" if diagram_file?(path)

    Rack::Mime.mime_type(Pathname(path).extname.downcase, "application/octet-stream")
  end

  private

  attr_reader :root

  def all_files
    @all_files ||= Dir.glob(root.join("**", "*").to_s, File::FNM_DOTMATCH)
      .map { Pathname(_1) }
      .select(&:file?)
      .sort_by(&:to_s)
  end

  def document_candidate_file?(path)
    !ignored_file?(path) && DOCUMENT_EXTENSIONS.include?(path.extname.downcase)
  end

  def build_document_candidate(path)
    logical_path = logical_path_for(path)
    frontmatter = markdown_file?(path) ? parse_frontmatter(path) : {}
    warnings = []

    attachment_paths = if diagram_file?(path)
      related_same_basename_files(path, logical_path)
    else
      markdown_attachment_paths(path, logical_path, warnings)
    end

    attachment_paths.unshift(path) unless attachment_paths.include?(path)

    DocumentCandidate.new(
      absolute_path: path,
      logical_path:,
      title: inferred_title(logical_path),
      slug: inferred_slug(logical_path),
      frontmatter:,
      document_kind: markdown_file?(path) ? "markdown" : "mixed",
      attachment_paths: attachment_paths.uniq.sort_by(&:to_s),
      warnings:
    )
  end

  def markdown_attachment_paths(path, logical_path, warnings)
    attachments = []
    referenced_targets(path).each do |target|
      resolved = resolve_relative_target(logical_path, target)
      next if resolved.blank?

      absolute_path = root.join(resolved)
      if absolute_path.file?
        attachments << absolute_path
      else
        warnings << "referenced file is missing: #{resolved}"
      end
    end

    attachments
  end

  def related_same_basename_files(path, logical_path)
    path_in_root = root.join(File.dirname(logical_path))
    base_name = path.basename.sub_ext("").to_s

    Dir.glob(path_in_root.join("#{base_name}.*").to_s)
      .map { Pathname(_1) }
      .select(&:file?)
  end

  def referenced_targets(path)
    content = File.read(path, encoding: "UTF-8")
    content.scan(LINK_PATTERN).filter_map do |target|
      value = Array(target).first.to_s.strip
      next if value.blank?
      next if value.start_with?("#")
      next if value.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
      next if value.start_with?("mailto:")

      value.split("#").first.presence
    end.uniq
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    []
  end

  def resolve_relative_target(logical_path, target)
    base_dir = Pathname(logical_path).dirname
    candidate = base_dir.join(target).cleanpath.to_s
    return if candidate == "." || candidate == ".." || candidate.start_with?("../")

    candidate
  end

  def parse_frontmatter(path)
    content = File.read(path, encoding: "UTF-8")
    return {} unless content.start_with?("---\n")

    closing_index = content.index("\n---\n", 4)
    return {} unless closing_index

    yaml = content[4...closing_index]
    parsed = YAML.safe_load(yaml, aliases: false)
    parsed.is_a?(Hash) ? parsed : {}
  rescue Psych::SyntaxError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    {}
  end

  def inferred_title(logical_path)
    path = Pathname(logical_path)
    base = path.basename.sub_ext("").to_s
    if README_BASENAMES.include?(base.downcase)
      directory = path.dirname.to_s
      return directory == "." ? "Home" : Pathname(directory).basename.to_s
    end

    base
  end

  def inferred_slug(logical_path)
    path = Pathname(logical_path)
    slug_source =
      if README_BASENAMES.include?(path.basename.sub_ext("").to_s.downcase)
        path.dirname.to_s
      else
        path.sub_ext("").to_s
      end
    slug_source = "home" if slug_source.blank? || slug_source == "."

    normalized = slug_source.split("/").map { |segment| segment.parameterize.presence || "part" }.join("-")
    normalized.presence || "document"
  end

  def logical_path_for(path)
    path.relative_path_from(root).to_s.tr("\\", "/")
  end

  def ignored_file?(path)
    logical_path = logical_path_for(path)
    basename = File.basename(logical_path).downcase
    return true if IGNORED_BASENAMES.include?(basename)
    return true if basename.start_with?("._")

    logical_path.split("/").any? { |segment| segment.casecmp("__MACOSX").zero? }
  end
end
