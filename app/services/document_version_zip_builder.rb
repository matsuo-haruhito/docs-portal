class DocumentVersionZipBuilder
  README_ENTRY_NAME = "README.txt"

  def initialize(version:, user:, zip_path_mode: :document_title, include_markdown_sources: true, include_attachments: true, pdf_only: false)
    @version = version
    @user = user
    @zip_path_mode = zip_path_mode.to_sym
    @include_markdown_sources = include_markdown_sources
    @include_attachments = include_attachments
    @pdf_only = pdf_only
  end

  def filename
    [
      version.document.slug,
      version.version_label
    ].map { sanitize_filename_component(_1) }.join("-") + ".zip"
  end

  def entries
    source_files + [readme_entry]
  end

  def empty?
    source_files.empty?
  end

  def to_binary
    StoredZipArchive.new(entries).to_binary
  end

  private

  attr_reader :version, :user, :zip_path_mode, :include_markdown_sources, :include_attachments, :pdf_only

  def source_files
    @source_files ||= version.document_files.order(:sort_order, :file_name).filter_map do |file|
      next unless file.downloadable_by?(user)
      next unless include_file?(file)
      next unless File.file?(file.absolute_path)

      StoredZipArchive::LocalFileEntry.new(
        archive_path: archive_path_for(file),
        absolute_path: file.absolute_path
      )
    end
  end

  def readme_entry
    StoredZipArchive::StringEntry.new(
      archive_path: README_ENTRY_NAME,
      content: readme_content
    )
  end

  def readme_content
    lines = []
    lines << "Export summary"
    lines << "document=#{version.document.slug}"
    lines << "version=#{version.version_label}"
    lines << "downloadable_files=#{source_files.size}"
    lines << "zip_path_mode=#{zip_path_mode}"
    lines << "include_markdown_sources=#{include_markdown_sources}"
    lines << "include_attachments=#{include_attachments}"
    lines << "pdf_only=#{pdf_only}"

    pdf_items = export_output_plan.items.select { pdf_file?(_1.document_file) && _1.watermark_text.present? }
    if pdf_items.any?
      lines << ""
      lines << "PDF watermark metadata"
      pdf_items.each do |item|
        lines << "- #{item.output_file_name}: #{item.watermark_text}"
      end
    end

    if source_files.empty?
      lines << ""
      lines << "No downloadable files are available for #{version.document.title} #{version.version_label}."
    end

    lines.join("\n") + "\n"
  end

  def export_output_plan
    @export_output_plan ||= ExportOutputPlan.new(
      project: version.document.project,
      viewer: user,
      files: export_plan_files,
      include_source_path: zip_path_mode == :source_path,
      watermark: true
    ).call
  end

  def export_plan_files
    @export_plan_files ||= version.document_files.order(:sort_order, :file_name).select { _1.downloadable_by?(user) }.select { include_file?(_1) }
  end

  def archive_path_for(file)
    return source_path_for(file) if zip_path_mode == :source_path

    path = file.file_name.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path).cleanpath.to_s

    if normalized.blank? || normalized == "." || normalized.start_with?("../") || normalized.include?("/../")
      return File.basename(file.file_name.to_s.presence || file.storage_key)
    end

    normalized
  end

  def source_path_for(file)
    ExportOutputPlan.new(
      project: version.document.project,
      viewer: user,
      files: [file],
      include_source_path: true,
      watermark: false
    ).call.items.first.zip_path
  end

  def include_file?(file)
    return false if pdf_only && !pdf_file?(file)
    return false if markdown_source_file?(file) && !include_markdown_sources
    return false if !markdown_source_file?(file) && !include_attachments

    true
  end

  def markdown_source_file?(file)
    file.effective_content_type.start_with?("text/markdown")
  end

  def pdf_file?(file)
    file.effective_content_type.start_with?("application/pdf") || file.file_name.to_s.downcase.end_with?(".pdf")
  end

  def sanitize_filename_component(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .gsub(/[\\\/:*?"<>|]/, "-")
      .squish
      .presence || "document"
  end
end
