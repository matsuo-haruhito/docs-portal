require "set"

class DocumentVersionsZipBuilder
  README_ENTRY_NAME = "README.txt"

  def initialize(versions:, user:, filename: "documents.zip", zip_path_mode: :document_title, include_markdown_sources: true, include_attachments: true, pdf_only: false)
    @versions = versions
    @user = user
    @filename = filename
    @zip_path_mode = zip_path_mode.to_sym
    @include_markdown_sources = include_markdown_sources
    @include_attachments = include_attachments
    @pdf_only = pdf_only
  end

  attr_reader :filename

  def entries
    @entries ||= build_entries
  end

  def to_binary
    StoredZipArchive.new(entries).to_binary
  end

  private

  attr_reader :versions, :user, :zip_path_mode, :include_markdown_sources, :include_attachments, :pdf_only

  def build_entries
    used_paths = Set.new
    file_entries = versions.flat_map do |version|
      version.document_files.order(:sort_order, :file_name).filter_map do |file|
        next unless file.downloadable_by?(user)
        next unless include_file?(file)
        next unless File.file?(file.absolute_path)

        archive_path = unique_path(path_for(version, file), used_paths)
        StoredZipArchive::LocalFileEntry.new(archive_path:, absolute_path: file.absolute_path)
      end
    end

    file_entries + [readme_entry(file_entries)]
  end

  def path_for(version, file)
    return source_path_for(version, file) if zip_path_mode == :source_path

    document_dir = safe_segment(version.document.slug)
    version_dir = safe_segment(version.version_label)
    file_path = file.file_name.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(file_path).cleanpath.to_s
    normalized = File.basename(file.file_name.to_s.presence || file.storage_key) if unsafe_path?(normalized)

    File.join(document_dir, version_dir, normalized)
  end

  def source_path_for(version, file)
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

  def unique_path(path, used_paths)
    candidate = path
    basename = File.basename(path, ".*")
    extension = File.extname(path)
    dirname = File.dirname(path)
    index = 2

    while used_paths.include?(candidate)
      candidate = File.join(dirname, "#{basename}-#{index}#{extension}")
      index += 1
    end

    used_paths << candidate
    candidate
  end

  def unsafe_path?(path)
    path.blank? || path == "." || path.start_with?("../") || path.include?("/../")
  end

  def safe_segment(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .gsub(/[\\\/:*?"<>|]/, "-")
      .squish
      .presence || "document"
  end

  def readme_entry(file_entries)
    StoredZipArchive::StringEntry.new(
      archive_path: README_ENTRY_NAME,
      content: readme_content(file_entries)
    )
  end

  def readme_content(file_entries)
    lines = []
    lines << "Export summary"
    lines << "project_documents=#{versions.size}"
    lines << "downloadable_files=#{file_entries.size}"
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

    if file_entries.empty?
      lines << ""
      lines << "No downloadable files are available for the selected documents."
    end

    lines.join("\n") + "\n"
  end

  def export_output_plan
    @export_output_plan ||= ExportOutputPlan.new(
      project: versions.first&.document&.project,
      viewer: user,
      files: export_plan_files,
      include_source_path: zip_path_mode == :source_path,
      watermark: true
    ).call
  end

  def export_plan_files
    @export_plan_files ||= versions.flat_map(&:document_files).select { _1.downloadable_by?(user) }.select { include_file?(_1) }
  end
end
