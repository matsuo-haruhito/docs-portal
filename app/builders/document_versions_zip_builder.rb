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
      selected_files_for(version).filter_map do |file|
        archive_path = path_resolver.multi_version_path(version:, file:, used_paths:)
        StoredZipArchive::LocalFileEntry.new(archive_path:, absolute_path: file.absolute_path)
      end
    end

    file_entries + [readme_entry(file_entries)]
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

    DocumentExport::ReadmeBuilder.new(
      lines:,
      pdf_items: pdf_watermark_items,
      empty_message: file_entries.empty? ? "No downloadable files are available for the selected documents." : nil
    ).call
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
    @export_plan_files ||= versions.flat_map { selected_files_for(_1) }
  end

  def selected_files_for(version)
    @selected_files_by_version ||= {}
    cache_key = version.id || version.object_id
    @selected_files_by_version[cache_key] ||= file_selector.call(version.document_files.order(:sort_order, :file_name))
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
