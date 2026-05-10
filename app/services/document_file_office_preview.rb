class DocumentFileOfficePreview
  OFFICE_EXTENSIONS = %w[.doc .docx .xls .xlsx .ppt .pptx].freeze

  class Error < StandardError; end

  def initialize(file:, user:)
    @file = file
    @user = user
  end

  def available?
    office_file? && connection.present?
  end

  def url
    raise Error, "Office preview is not available" unless available?
    raise Error, "File not found" unless File.exist?(file.absolute_path)

    MicrosoftGraphClient.new(connection:).preview_url_for_upload(
      file_path: file.absolute_path,
      file_name: file.file_name
    )
  end

  private

  attr_reader :file, :user

  def office_file?
    File.extname(file.file_name.to_s).downcase.in?(OFFICE_EXTENSIONS)
  end

  def connection
    @connection ||= MicrosoftGraphConnection
      .enabled_only
      .where(project: file.document_version.document.project)
      .order(:id)
      .first
  end
end
