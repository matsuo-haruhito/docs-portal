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
    preview_url.present?
  end

  def url
    preview_url.presence || raise(Error, unavailable_message)
  end

  def unavailable_message
    details = {
      document_file_id: file.id,
      document_version_id: file.document_version_id,
      document_id: file.document_version&.document_id,
      source_commit_hash: file.document_version&.source_commit_hash,
      google_drive_item_found: google_drive_item.present?,
      external_item_id: external_item_id,
      web_view_link_present: web_view_link.present?,
      source_mime_type: source_mime_type,
      storage_key: file.storage_key
    }.compact

    "Google Drive preview is not available (#{details.map { |key, value| "#{key}=#{value}" }.join(', ')})"
  end

  private

  attr_reader :file

  def preview_url
    @preview_url ||= begin
      if external_item_id.present?
        preview_url_for(external_item_id, source_mime_type)
      else
        normalized_web_view_link
      end
    end
  end

  def google_drive_item
    @google_drive_item ||= direct_google_drive_item || version_google_drive_item || document_google_drive_item || source_commit_google_drive_item || storage_key_google_drive_item
  end

  def direct_google_drive_item
    google_drive_items.where(document_file: file).order(id: :desc).first
  end

  def version_google_drive_item
    google_drive_items.where(document_version: file.document_version).order(id: :desc).first
  end

  def document_google_drive_item
    google_drive_items.where(document: file.document_version.document).order(id: :desc).first
  end

  def source_commit_google_drive_item
    external_id = file.document_version.source_commit_hash.to_s.delete_prefix(GOOGLE_DRIVE_SOURCE_PREFIX)
    return if external_id.blank? || external_id == file.document_version.source_commit_hash

    google_drive_items.where(external_item_id: external_id).order(id: :desc).first
  end

  def storage_key_google_drive_item
    source_id, version_id = file.storage_key.to_s.match(%r{\Aexternal_folder_syncs/(\d+)/(\d+)/})&.captures
    return if source_id.blank?

    google_drive_items.where(external_folder_sync_source_id: source_id, document_version_id: version_id.presence || file.document_version_id).order(id: :desc).first ||
      google_drive_items.where(external_folder_sync_source_id: source_id, document: file.document_version.document).order(id: :desc).first
  end

  def google_drive_items
    ExternalFolderSyncItem
      .joins(:external_folder_sync_source)
      .where(external_folder_sync_sources: { provider: ExternalFolderSyncSource.providers.fetch("google_drive") })
  end

  def external_item_id
    google_drive_item&.external_item_id.presence || external_item_id_from_source_commit
  end

  def external_item_id_from_source_commit
    value = file.document_version.source_commit_hash.to_s
    value.delete_prefix(GOOGLE_DRIVE_SOURCE_PREFIX) if value.start_with?(GOOGLE_DRIVE_SOURCE_PREFIX)
  end

  def source_mime_type
    google_drive_item&.provider_metadata&.fetch("source_mime_type", nil).presence || google_drive_item&.mime_type
  end

  def web_view_link
    google_drive_item&.provider_metadata&.fetch("web_view_link", nil).presence
  end

  def normalized_web_view_link
    link = web_view_link.to_s
    return if link.blank?

    file_id = link[%r{/d/([^/?#]+)}, 1] || link[%r{[?&]id=([^&#]+)}, 1]
    return preview_url_for(URI.decode_www_form_component(file_id), source_mime_type) if file_id.present?

    link
  end

  def preview_url_for(file_id, mime_type)
    template = GOOGLE_DOCS_PREVIEW_URLS[mime_type.to_s]
    return format(template, id: ERB::Util.url_encode(file_id)) if template.present?

    "https://drive.google.com/file/d/#{ERB::Util.url_encode(file_id)}/preview"
  end
end
