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
