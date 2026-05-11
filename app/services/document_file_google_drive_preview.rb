class DocumentFileGoogleDrivePreview
  GOOGLE_DOCS_PREVIEW_URLS = {
    "application/vnd.google-apps.document" => "https://docs.google.com/document/d/%<id>s/preview",
    "application/vnd.google-apps.spreadsheet" => "https://docs.google.com/spreadsheets/d/%<id>s/preview",
    "application/vnd.google-apps.presentation" => "https://docs.google.com/presentation/d/%<id>s/preview",
    "application/vnd.google-apps.drawing" => "https://docs.google.com/drawings/d/%<id>s/preview"
  }.freeze

  class Error < StandardError; end

  def initialize(file:)
    @file = file
  end

  def available?
    google_drive_item.present? && external_item_id.present?
  end

  def url
    raise Error, "Google Drive preview is not available" unless available?

    preview_url_for(external_item_id, source_mime_type)
  end

  private

  attr_reader :file

  def google_drive_item
    @google_drive_item ||= file.external_folder_sync_items
      .joins(:external_folder_sync_source)
      .where(external_folder_sync_sources: { provider: ExternalFolderSyncSource.providers.fetch(:google_drive) })
      .order(:id)
      .first
  end

  def external_item_id
    google_drive_item&.external_item_id
  end

  def source_mime_type
    google_drive_item&.provider_metadata&.fetch("source_mime_type", nil).presence || google_drive_item&.mime_type
  end

  def preview_url_for(file_id, mime_type)
    template = GOOGLE_DOCS_PREVIEW_URLS[mime_type.to_s]
    return format(template, id: ERB::Util.url_encode(file_id)) if template.present?

    "https://drive.google.com/file/d/#{ERB::Util.url_encode(file_id)}/preview"
  end
end
