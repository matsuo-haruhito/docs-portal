namespace :google_drive_preview_uploads do
  desc "Delete expired Google Drive preview upload files and mark them as deleted"
  task cleanup: :environment do
    limit = ENV.fetch("LIMIT", "100").to_i
    GoogleDrivePreviewUploadCleanupJob.perform_now(limit: limit.positive? ? limit : 100)
  end
end
