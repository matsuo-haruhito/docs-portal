class RecurringJobDefinition
  Definition = Data.define(:job_key, :job_class, :queue_name, :interval_seconds, :args_json, :description, :enabled, :allow_overlap)

  DEFAULT_INTERVAL_SECONDS = 24.hours.to_i
  DOCUSAURUS_PREVIEW_RECONCILIATION_JOB_KEY = "reconcile_docusaurus_preview_builds"
  ROLLOUT_GATED_JOB_KEYS = %w[
    retry_failed_webhook_deliveries
    recover_generated_file_events
    reconcile_external_folder_sync_webhook_events
  ].freeze
  RUNNER_PROTOCOL_V2_JOB_KEYS = [
    *ROLLOUT_GATED_JOB_KEYS,
    DOCUSAURUS_PREVIEW_RECONCILIATION_JOB_KEY
  ].freeze
  V2_RUNNER_PROTOCOL_VERSION = 2

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
    ),
    Definition.new(
      job_key: "retry_failed_webhook_deliveries",
      job_class: "WebhookDeliveryAutoRetryJob",
      queue_name: "default",
      interval_seconds: 5.minutes.to_i,
      args_json: {},
      description: "一時的に失敗したWebhook送信を同じ送信履歴で最大3回まで再送します。",
      enabled: true,
      allow_overlap: false
    ),
    Definition.new(
      job_key: "recover_generated_file_events",
      job_class: "GeneratedFileEventDispatchJob",
      queue_name: "default",
      interval_seconds: 5.minutes.to_i,
      args_json: {},
      description: "未処理または処理中のまま停止した生成ファイルイベントを回収します。",
      enabled: true,
      allow_overlap: false
    ),
    Definition.new(
      job_key: "reconcile_external_folder_sync_webhook_events",
      job_class: "ExternalFolderSyncWebhookEventReconciliationJob",
      queue_name: "default",
      interval_seconds: 2.minutes.to_i,
      args_json: { limit: 100 },
      description: "同期実行中に受信した外部フォルダWebhook通知を追随同期へ集約します。",
      enabled: true,
      allow_overlap: false
    ),
    Definition.new(
      job_key: DOCUSAURUS_PREVIEW_RECONCILIATION_JOB_KEY,
      job_class: "DocusaurusPreviewBuildReconciliationJob",
      queue_name: "default",
      interval_seconds: 5.minutes.to_i,
      args_json: { limit: 100 },
      description: "Markdown版のDocusaurusプレビュー状態と成果物を有限回の再試行で整合させます。",
      enabled: true,
      allow_overlap: false
    ),
    Definition.new(
      job_key: "sync_git_import_sources",
      job_class: "GitImportSourcesSyncJob",
      queue_name: "default",
      interval_seconds: 15.minutes.to_i,
      args_json: {},
      description: "有効なGit pull型インポート元を定期同期します。",
      enabled: true,
      allow_overlap: false
    )
  ].freeze

  class << self
    def all
      return DEFINITIONS if JobReliability::RolloutGate.enabled?

      DEFINITIONS.reject { rollout_gated_job_key?(_1.job_key) }
    end

    def find(job_key)
      all.find { _1.job_key == job_key.to_s }
    end

    def rollout_gated_job_keys
      ROLLOUT_GATED_JOB_KEYS
    end

    def rollout_gated_job_key?(job_key)
      ROLLOUT_GATED_JOB_KEYS.include?(job_key.to_s)
    end

    def runner_protocol_v2_job_keys
      RUNNER_PROTOCOL_V2_JOB_KEYS
    end

    def runner_protocol_v2_job_key?(job_key)
      RUNNER_PROTOCOL_V2_JOB_KEYS.include?(job_key.to_s)
    end

    def docusaurus_preview_reconciliation_job_key?(job_key)
      job_key.to_s == DOCUSAURUS_PREVIEW_RECONCILIATION_JOB_KEY
    end
  end
end
