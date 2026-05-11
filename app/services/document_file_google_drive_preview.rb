class DocumentFileGoogleDrivePreview
  GOOGLE_DOCS_PREVIEW_URLS = {
    "application/vnd.google-apps.document" => "https://docs.google.com/document/d/%<id>s/preview",
    "application/vnd.google-apps.spreadsheet" => "https://docs.google.com/spreadsheets/d/%<id>s/preview",
    "application/vnd.google-apps.presentation" => "https://docs.google.com/presentation/d/%<id>s/preview",
    "application/vnd.google-apps.drawing" => "https://docs.google.com/drawings/d/%<id>s/preview"
  }.freeze

  GOOGLE_DRIVE_SOURCE_PREFIX = "google-drive:".freeze

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
    @google_drive_item ||= direct_google_drive_item || version_google_drive_item || document_google_drive_item || source_commit_google_drive_item
  end

  def direct_google_drive_item
    google_drive_items.where(document_file: file).order(:id).first
  end

  def version_google_drive_item
    google_drive_items.where(document_version: file.document_version).order(:id).first
  end

  def document_google_drive_item
    google_drive_items.where(document: file.document_version.document).order(:id).first
  end

  def source_commit_google_drive_item
    external_id = file.document_version.source_commit_hash.to_s.delete_prefix(GOOGLE_DRIVE_SOURCE_PREFIX)
    return if external_id.blank? || external_id == file.document_version.source_commit_hash

    google_drive_items.where(external_item_id: external_id).order(:id).first
  end

  def google_drive_items
    ExternalFolderSyncItem
      .joins(:external_folder_sync_source)
      .where(external_folder_sync_sources: { provider: ExternalFolderSyncSource.providers.fetch("google_drive") })
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
