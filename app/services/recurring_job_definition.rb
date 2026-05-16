class RecurringJobDefinition
  Definition = Data.define(:job_key, :job_class, :queue_name, :interval_seconds, :args_json, :description, :enabled, :allow_overlap)

  DEFAULT_INTERVAL_SECONDS = 24.hours.to_i

  DEFINITIONS = [
    Definition.new(
      job_key: "cleanup_google_drive_preview_uploads",
      job_class: "GoogleDrivePreviewUploadCleanupJob",
      queue_name: "default",
      interval_seconds: DEFAULT_INTERVAL_SECONDS,
      args_json: { limit: 500 },
      description: "期限切れのGoogle Drive preview用アップロードファイルを削除します。",
      enabled: true,
      allow_overlap: false
    ),
    Definition.new(
      job_key: "cleanup_microsoft_graph_preview_uploads",
      job_class: "MicrosoftGraphPreviewUploadCleanupJob",
      queue_name: "default",
      interval_seconds: DEFAULT_INTERVAL_SECONDS,
      args_json: { limit: 500 },
      description: "期限切れのMicrosoft Graph preview用アップロードファイルを削除します。",
      enabled: true,
      allow_overlap: false
    ),
    Definition.new(
      job_key: "renew_google_drive_external_folder_sync_webhooks",
      job_class: "ExternalFolderSyncSubscriptionRenewalJob",
      queue_name: "default",
      interval_seconds: 6.hours.to_i,
      args_json: { limit: 100 },
      description: "期限が近いGoogle Drive外部フォルダ同期Webhook購読を更新します。",
      enabled: true,
      allow_overlap: false
    )
  ].freeze

  class << self
    def all
      DEFINITIONS
    end

    def find(job_key)
      all.find { _1.job_key == job_key.to_s }
    end
  end
end
