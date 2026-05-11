namespace :microsoft_graph_preview_uploads do
  desc "Delete expired Microsoft Graph preview upload files and mark them as deleted"
  task cleanup: :environment do
    limit = ENV.fetch("LIMIT", "100").to_i
    MicrosoftGraphPreviewUploadCleanupJob.perform_now(limit: limit.positive? ? limit : 100)
  end
end
