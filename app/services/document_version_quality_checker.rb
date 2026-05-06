require "set"

class DocumentVersionQualityChecker
  Check = Data.define(:key, :severity, :message, :detail) do
    def error?
      severity == :error
    end

    def warning?
      severity == :warning
    end

    def info?
      severity == :info
    end
  end

  Result = Data.define(:document_version, :checks) do
    def errors
      checks.select(&:error?)
    end

    def warnings
      checks.select(&:warning?)
    end

    def infos
      checks.select(&:info?)
    end

    def pass?
      errors.empty?
    end
  end

  INTERNAL_ONLY_PATTERNS = [
    /社内(?:限|向|用|秘)/,
    /internal[\s_-]*only/i,
    /confidential/i
  ].freeze
  MARKDOWN_REFERENCE_PATTERN = /
    (!)?             # image marker
    \[[^\]]*\]
    \(
      \s*
      (<?[^)\s>]+>?) # target
      [^)]*
    \)
  /x.freeze
  IMAGE_EXTENSIONS = %w[
    .png
    .jpg
    .jpeg
    .gif
    .svg
    .webp
    .bmp
  ].freeze
  MARKDOWN_EXTENSIONS = %w[
    .md
    .markdown
  ].freeze

  def initialize(document_version)
    @document_version = document_version
    @document = document_version.document
  end

  def call
    Result.new(document_version:, checks: [
      title_check,
      category_check,
      document_kind_check,
      visibility_policy_check,
      source_path_check,
      rendered_site_check,
      attachment_count_check,
      *document_file_checks,
      *markdown_reference_checks,
      internal_only_text_check
    ].compact)
  end

  private

  attr_reader :document_version, :document

  def title_check
    return info(:title, "Document title is present", document.title) if document.title.present?

    error(:title, "Document title is missing")
  end

  def category_check
    return info(:category, "Document category is set", document.category) if document.category.present?

    warning(:category, "Document category is missing")
  end

  def document_kind_check
    return info(:document_kind, "Document kind is set", document.document_kind) if document.document_kind.present?

    warning(:document_kind, "Document kind is missing")
  end

  def visibility_policy_check
    return info(:visibility_policy, "Visibility policy is set", document.visibility_policy) if document.visibility_policy.present?

    warning(:visibility_policy, "Visibility policy is missing")
  end

  def source_path_check
    return info(:source_relative_path, "Source path is set", document_version.source_relative_path) if document_version.source_relative_path.present?

    info(:source_relative_path, "Source path is not set")
  end

  def rendered_site_check
    return if document_version.site_build_path.blank?
    return info(:rendered_site, "Rendered site entry exists", document_version.site_entry_relative_path) if document_version.rendered_site_available?

    error(:rendered_site, "Rendered site entry is missing", document_version.site_entry_relative_path)
  end

  def attachment_count_check
    count = document_version.document_files.size
    return warning(:document_files, "No document files are attached") if count.zero?

    info(:document_files, "Document files are attached", count)
  end

  def document_file_checks
    document_version.document_files.flat_map do |file|
      [
        document_file_presence_check(file),
        document_file_scan_check(file)
      ].compact
    end
  end

  def document_file_presence_check(file)
    return info(:document_file_exists, "Document file exists", file.file_name) if file.absolute_path.file?

    error(:document_file_missing, "Document file is missing", file.storage_key)
  rescue ActiveRecord::RecordNotFound => e
    error(:document_file_missing, "Document file storage path is invalid", e.message)
  end

  def document_file_scan_check(file)
    return info(:document_file_scan, "Document file scan is clean", file.file_name) if file.scan_clean?
    return warning(:document_file_scan, "Document file scan is pending", file.file_name) if file.scan_pending?

    error(:document_file_scan, "Document file scan is not clean", "#{file.file_name}: #{file.scan_status}")
  end

  def markdown_reference_checks
    markdown_source_files.flat_map do |file|
      parse_markdown_targets(file).filter_map do |reference|
        next if markdown_reference_resolved?(reference)

        missing_reference_check(reference)
      end
    end
  end

  def markdown_source_files
    document_version.document_files.select do |file|
      file.effective_content_type.start_with?("text/markdown") && file.absolute_path.file?
    rescue ActiveRecord::RecordNotFound
      false
    end
  end

  def parse_markdown_targets(file)
    body = file.absolute_path.read
    body.scan(MARKDOWN_REFERENCE_PATTERN).map do |image_marker, raw_target|
      target = normalize_markdown_target(raw_target)
      next if target.blank? || ignored_markdown_target?(target)

      {
        kind: reference_kind(target, image_marker.present?),
        file_name: file.file_name,
        target:,
        resolved_target: resolve_reference_target(file, target)
      }
    end.compact
  rescue Errno::ENOENT
    []
  end

  def normalize_markdown_target(raw_target)
    value = raw_target.to_s.strip
    value = value.delete_prefix("<").delete_suffix(">")
    value.split(/\s+/, 2).first.to_s
  end

  def ignored_markdown_target?(target)
    target.start_with?("#") || target.match?(/\A[a-z][a-z0-9+\-.]*:/i)
  end

  def reference_kind(target, image_reference)
    return :image if image_reference || IMAGE_EXTENSIONS.include?(File.extname(target).downcase)
    return :document_link if document_link_target?(target)

    :attachment
  end

  def document_link_target?(target)
    extension = File.extname(target_without_suffixes(target)).downcase
    extension.blank? || MARKDOWN_EXTENSIONS.include?(extension) || extension == ".html"
  end

  def target_without_suffixes(target)
    target.to_s.split("#", 2).first.split("?", 2).first
  end

  def resolve_reference_target(file, target)
    relative_target = target_without_suffixes(target)
    base_dir = markdown_source_directory(file)
    Pathname.new(base_dir.to_s).join(relative_target).cleanpath.to_s
  end

  def markdown_source_directory(file)
    source_path = document_version.source_relative_path.presence || file.file_name
    path = Pathname.new(source_path)
    path.dirname.to_s == "." ? "" : path.dirname.to_s
  end

  def markdown_reference_resolved?(reference)
    case reference[:kind]
    when :document_link
      available_document_targets.include?(reference[:resolved_target]) ||
        available_document_targets.include?("#{reference[:resolved_target]}.md") ||
        available_document_targets.include?("#{reference[:resolved_target]}.markdown") ||
        available_document_targets.include?(Pathname.new(reference[:resolved_target]).join("README.md").to_s) ||
        available_document_targets.include?(Pathname.new(reference[:resolved_target]).join("index.md").to_s)
    when :image, :attachment
      available_attachment_targets.include?(File.basename(reference[:resolved_target])) ||
        available_attachment_targets.include?(reference[:resolved_target])
    else
      false
    end
  end

  def available_document_targets
    @available_document_targets ||= DocumentVersion
      .joins(:document)
      .where(documents: { project_id: document.project_id })
      .where.not(source_relative_path: [nil, ""])
      .pluck(:source_relative_path)
      .to_set
  end

  def available_attachment_targets
    @available_attachment_targets ||= document_version.document_files.filter_map do |file|
      next unless file.absolute_path.file?

      [file.file_name, file.storage_key]
    rescue ActiveRecord::RecordNotFound
      next
    end.flatten.to_set
  end

  def missing_reference_check(reference)
    detail = "#{reference[:file_name]} -> #{reference[:target]}"

    case reference[:kind]
    when :document_link
      error(:markdown_link_missing, "Markdown link target is missing", detail)
    when :image
      error(:markdown_image_missing, "Markdown image target is missing", detail)
    when :attachment
      error(:markdown_attachment_missing, "Markdown attachment target is missing", detail)
    end
  end

  def internal_only_text_check
    text = [document.title, document_version.search_body_text].compact.join("\n")
    pattern = INTERNAL_ONLY_PATTERNS.find { text.match?(_1) }
    return unless pattern

    warning(:internal_only_text, "Document contains internal-only wording", pattern.source)
  end

  def info(key, message, detail = nil)
    Check.new(key:, severity: :info, message:, detail:)
  end

  def warning(key, message, detail = nil)
    Check.new(key:, severity: :warning, message:, detail:)
  end

  def error(key, message, detail = nil)
    Check.new(key:, severity: :error, message:, detail:)
  end
end
