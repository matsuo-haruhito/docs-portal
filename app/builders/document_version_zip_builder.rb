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
    ].map { path_resolver.filename_component(_1) }.join("-") + ".zip"
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
    @source_files ||= selected_files.filter_map do |file|
      StoredZipArchive::LocalFileEntry.new(
        archive_path: path_resolver.single_version_path(version:, file:),
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

    DocumentExport::ReadmeBuilder.new(
      lines:,
      pdf_items: pdf_watermark_items,
      empty_message: source_files.empty? ? "No downloadable files are available for #{version.document.title} #{version.version_label}." : nil
    ).call
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
    @export_plan_files ||= selected_files
  end

  def selected_files
    @selected_files ||= file_selector.call(version.document_files.order(:sort_order, :file_name))
  end

  def pdf_watermark_items
    export_output_plan.items.select { file_selector.pdf_file?(_1.document_file) && _1.watermark_text.present? }
  end

  def file_selector
    @file_selector ||= DocumentExport::FileSelector.new(
      user:,
      include_markdown_sources:,
      include_attachments:,
      pdf_only:
    )
  end

  def path_resolver
    @path_resolver ||= DocumentExport::PathResolver.new(user:, zip_path_mode:)
  end
end
