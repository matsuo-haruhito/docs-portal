class DocumentFileOfficePreview
  OFFICE_EXTENSIONS = %w[.doc .docx .xls .xlsx .ppt .pptx].freeze
  SIMPLE_UPLOAD_LIMIT_BYTES = 250.megabytes

  class Error < StandardError; end
  class FileTooLargeError < Error; end

  def initialize(file:, user:)
    @file = file
    @user = user
  end

  def available?
    office_file? && (microsoft_graph_available? || google_drive_preview.available? || google_drive_upload_preview.available?)
  end

  def too_large_for_simple_upload?
    file.file_size.to_i > SIMPLE_UPLOAD_LIMIT_BYTES
  end

  def url
    raise Error, "Office preview is not available" unless office_file?

    if microsoft_graph_available? && !too_large_for_simple_upload?
      begin
        return microsoft_graph_preview_url
      rescue Error, MicrosoftGraphClient::Error => e
        Rails.logger.info("Microsoft Graph Office preview failed; trying Google Drive fallback: #{e.message}")
      end
    end

    return google_drive_preview.url if google_drive_preview.available?
    return google_drive_upload_preview.url if google_drive_upload_preview.available?

    raise FileTooLargeError, "Office preview is not available for files over 250MB" if microsoft_graph_available? && too_large_for_simple_upload?
    raise Error, [google_drive_preview.unavailable_message, google_drive_upload_preview.unavailable_message].join("; ")
  end

  private

  attr_reader :file, :user

  def office_file?
    File.extname(file.file_name.to_s).downcase.in?(OFFICE_EXTENSIONS)
  end

  def microsoft_graph_available?
    connection.present?
  end

  def microsoft_graph_preview_url
    raise Error, "File not found" unless File.exist?(file.absolute_path)

    MicrosoftGraphClient.new(connection:).preview_url_for_upload(
      file_path: file.absolute_path,
      file_name: file.file_name,
      document_file: file
    )
  end

  def google_drive_preview
    @google_drive_preview ||= DocumentFileGoogleDrivePreview.new(file:)
  end

  def google_drive_upload_preview
    @google_drive_upload_preview ||= DocumentFileGoogleDriveUploadPreview.new(file:)
  end

  def connection
    @connection ||= MicrosoftGraphConnection
      .enabled_only
      .where(project: file.document_version.document.project)
      .order(:id)
      .first
  end
end
