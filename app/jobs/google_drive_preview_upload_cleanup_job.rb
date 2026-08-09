class GoogleDrivePreviewUploadCleanupJob < ApplicationJob
  queue_as :default

  def perform(limit: 100)
    errors = cleanup_candidates(limit).filter_map do |upload|
      cleanup_upload(upload)
      nil
    rescue StandardError => e
      upload.update!(last_error_message: e.message)
      Rails.logger.error("Google Drive preview cleanup failed upload_id=#{upload.id}: #{e.class}: #{e.message}")
      e
    end
    raise errors.first if errors.any?
  end

  private

  def cleanup_candidates(limit)
    DocumentFileGoogleDrivePreviewUpload
      .expired_or_deleted_pending
      .order(:expires_at, :id)
      .limit(limit.to_i.clamp(1, 500))
      .to_a
  end

  def cleanup_upload(upload)
    DocumentFileGoogleDrivePreviewUploadCleanup.new(upload:).call
  end
end
