module DocumentDownloadsHelper
  def document_version_download_file(document_version)
    return unless document_version

    files = document_version.document_files.order(:sort_order, :id).select { _1.downloadable_by?(current_user) }
    return if files.empty?

    files.detect { |file| document_download_source_file?(document_version, file) } ||
      files.detect { |file| !file.embeddable_viewer_file? } ||
      files.first
  end

  private

  def document_download_source_file?(document_version, document_file)
    source_file_name = document_version.source_file_name.to_s.presence
    source_extension = document_version.source_extension.to_s.delete_prefix(".").downcase.presence
    file_name = document_file.file_name.to_s.tr("\\", "/")
    basename = File.basename(file_name)

    return true if source_file_name.present? && basename == File.basename(source_file_name.tr("\\", "/"))

    file_extension = File.extname(basename).delete_prefix(".").downcase.presence
    source_extension.present? && file_extension == source_extension && !document_download_generated_viewer_file?(document_file)
  end

  def document_download_generated_viewer_file?(document_file)
    extension = File.extname(document_file.file_name.to_s).downcase
    content_type = document_file.effective_content_type.to_s

    extension.in?(%w[.html .htm]) || content_type.start_with?("text/html")
  end
end
