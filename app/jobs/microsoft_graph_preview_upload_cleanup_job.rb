class MicrosoftGraphPreviewUploadCleanupJob < ApplicationJob
  queue_as :default

  def perform(limit: 100)
    DocumentFileMicrosoftGraphPreviewUpload.expired_or_deleted_pending.order(:expires_at, :id).limit(limit).find_each do |upload|
      cleanup_upload(upload)
    end
  end

  private

  def cleanup_upload(upload)
    DocumentFileMicrosoftGraphPreviewUploadCleanup.new(upload:).call
  rescue => e
    upload.update!(last_error_message: e.message)
    raise
  end
end
