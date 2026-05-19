require "erb"
require "fileutils"
require "securerandom"

class ManualDocumentUpload
  Result = Struct.new(:document, :version, :source_path, keyword_init: true)

  SEARCH_TEXT_EXTENSIONS = %w[
    .md
    .markdown
    .mdx
    .txt
    .csv
    .json
    .yml
    .yaml
  ].freeze

  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze

  def initialize(project:, actor:, uploaded_file:, source_path: nil, target_document: nil)
    @project = project
    @actor = actor
    @uploaded_file = uploaded_file
    @source_path = source_path
    @target_document = target_document
  end

  def call
    filename = safe_filename(uploaded_file.original_filename)
    directory = target_directory
    full_source_path = normalize_source_path(directory, filename)
    document = resolve_document(full_source_path, filename)

    Document.transaction do
      document.save! if document.new_record?
      version = create_version!(document, full_source_path)
      create_document_file!(version, full_source_path, filename)
      build_manual_html_preview!(version, full_source_path) if markdown_extension?(full_source_path)
      Result.new(document:, version:, source_path: full_source_path)
    end
  end

  private

  attr_reader :project, :actor, :uploaded_file, :source_path, :target_document

  def target_directory
    return document_source_directory(target_document) if target_document

    normalize_directory(source_path)
  end

  def resolve_document(full_source_path, filename)
    if target_document && same_filename?(target_document, filename)
      return target_document
    end

    existing_document_for(full_source_path) || build_document(full_source_path, filename)
  end

  def existing_document_for(full_source_path)
    version = DocumentVersion
      .joins(:document)
      .where(documents: { project_id: project.id, archived_at: nil })
      .where(source_relative_path: full_source_path)
      .order(created_at: :desc, id: :desc)
      .first
    version&.document
  end

  def build_document(full_source_path, filename)
    project.documents.build(
      title: title_for(filename),
      slug: unique_slug_for(full_source_path),
      category: :other,
      document_kind: document_kind_for(filename),
      visibility_policy: :internal_only,
      importance_level: :normal,
      recommended_sort_order: 100
    )
  end

  def create_version!(document, full_source_path)
    document.document_versions.create!(
      version_label: version_label,
      status: :draft,
      source_commit_hash: "manual-upload",
      changelog_summary: "Manual file upload",
      published_at: nil,
      published_by_user: nil
    ).tap do |version|
      version.assign_source_path_metadata!(source_path: full_source_path, snapshot_kind: snapshot_kind_for(full_source_path))
      version.save!
    end
  end

  def create_document_file!(version, full_source_path, filename)
    storage_key = storage_key_for(version, filename)
    destination = DocumentFile.storage_root.join(storage_key)
    FileUtils.mkdir_p(destination.parent)
    uploaded_file.rewind if uploaded_file.respond_to?(:rewind)
    FileUtils.cp(uploaded_file.tempfile.path, destination)

    version.document_files.create!(
      file_name: full_source_path,
      content_type: content_type_for(filename),
      storage_key: storage_key,
      file_size: File.size(destination),
      sort_order: 0,
      scan_status: :scan_pending
    ).tap do |document_file|
      document_file.assign_search_text_from_path!(full_source_path)
      document_file.save!
    end

    assign_version_search_text!(version, destination, full_source_path)
  end

  def assign_version_search_text!(version, destination, full_source_path)
    return unless searchable_text_extension?(full_source_path)

    text = File.read(destination, encoding: "UTF-8")
    version.assign_search_body_text_from_markdown!(markdown: text, source_path: full_source_path)
    version.save!
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    version.update!(search_body_text: DocumentVersion.search_text_for(full_source_path))
  end

  def build_manual_html_preview!(version, full_source_path)
    source_file = version.document_files.order(:sort_order, :id).first
    return unless source_file

    markdown = source_file.absolute_path.read(encoding: "UTF-8", invalid: :replace, undef: :replace)
    site_path = DocumentVersion.normalize_site_page_path(full_source_path)
    destination = version.site_root_absolute_path.join(site_path, "index.html")
    FileUtils.mkdir_p(destination.parent)
    destination.write(manual_html_for(markdown, title: version.document.title), encoding: "UTF-8")
    version.update!(markdown_entry_path: full_source_path, site_build_path: site_path)
  end

  def manual_html_for(markdown, title:)
    escaped_title = ERB::Util.html_escape(title)
    body = markdown.lines.map { |line| manual_markdown_line_to_html(line) }.join("\n")

    <<~HTML
      <!doctype html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>#{escaped_title}</title>
        </head>
        <body>
          <main class="markdown manual-upload-preview">
            #{body}
          </main>
        </body>
      </html>
    HTML
  end

  def manual_markdown_line_to_html(line)
    stripped = line.chomp
    escaped = ERB::Util.html_escape(stripped)

    case stripped
    when /\A#\s+(.+)/
      "<h1>#{ERB::Util.html_escape(Regexp.last_match(1))}</h1>"
    when /\A##\s+(.+)/
      "<h2>#{ERB::Util.html_escape(Regexp.last_match(1))}</h2>"
    when /\A###\s+(.+)/
      "<h3>#{ERB::Util.html_escape(Regexp.last_match(1))}</h3>"
    when /\A[-*]\s+(.+)/
      "<p>#{escaped}</p>"
    when ""
      ""
    else
      "<p>#{escaped}</p>"
    end
  end

  def searchable_text_extension?(path)
    File.extname(path).downcase.in?(SEARCH_TEXT_EXTENSIONS)
  end

  def markdown_extension?(path)
    File.extname(path).downcase.in?(MARKDOWN_EXTENSIONS)
  end

  def storage_key_for(version, filename)
    safe = safe_filename(filename)
    "manual_uploads/#{project.id}/#{version.public_id}/#{safe}"
  end

  def version_label
    "manual-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(3)}"
  end

  def same_filename?(document, filename)
    document_source_file_name(document).to_s == filename.to_s
  end

  def document_source_directory(document)
    version = source_version_for(document)
    normalize_directory(version&.source_directory.presence || directory_from_path(version&.source_relative_path))
  end

  def document_source_file_name(document)
    version = source_version_for(document)
    version&.source_file_name.presence || File.basename(version&.source_relative_path.to_s)
  end

  def source_version_for(document)
    document&.latest_version || document&.document_versions&.order(created_at: :desc, id: :desc)&.first
  end

  def directory_from_path(path)
    return if path.blank?

    normalized = DocumentVersion.normalize_source_relative_path!(path)
    dirname = File.dirname(normalized)
    dirname == "." ? nil : dirname
  end

  def normalize_source_path(directory, filename)
    raw_path = [normalize_directory(directory), filename].compact_blank.join("/")
    DocumentVersion.normalize_source_relative_path!(raw_path)
  end

  def normalize_directory(value)
    return if value.blank?

    path = value.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path).cleanpath.to_s
    return if normalized.blank? || normalized == "."
    raise ApplicationError::BadRequest, "アップロード先フォルダが不正です。" if normalized == ".." || normalized.start_with?("../")

    normalized
  end

  def safe_filename(value)
    filename = File.basename(value.to_s.tr("\\", "/")).presence
    raise ApplicationError::BadRequest, "ファイル名が不正です。" if filename.blank? || filename.include?("\0") || filename == "." || filename == ".."

    filename
  end

  def title_for(filename)
    File.basename(filename, File.extname(filename)).presence || filename
  end

  def document_kind_for(filename)
    case File.extname(filename).downcase
    when ".md", ".markdown", ".mdx"
      :markdown
    when ".pdf"
      :pdf
    when ".xls", ".xlsx", ".xlsm"
      :excel
    when ".doc", ".docx"
      :word
    else
      :mixed
    end
  end

  def snapshot_kind_for(path)
    case File.extname(path).downcase
    when ".md", ".markdown", ".mdx"
      "received_markdown"
    when ".pdf"
      "pdf_generated"
    else
      "attachment"
    end
  end

  def content_type_for(filename)
    ext = File.extname(filename).downcase
    DocumentFile::EXTENSION_CONTENT_TYPES.fetch(ext) do
      uploaded_file.content_type.presence || Rack::Mime.mime_type(ext, "application/octet-stream")
    end
  end

  def unique_slug_for(full_source_path)
    base = Pathname.new(full_source_path).sub_ext("").to_s
    normalized = base.split("/").map { |segment| segment.parameterize.presence || "part" }.join("-")
    candidate = normalized.presence || "document"
    suffix = 2

    while project.documents.exists?(slug: candidate)
      candidate = "#{normalized}-#{suffix}"
      suffix += 1
    end

    candidate
  end
end
