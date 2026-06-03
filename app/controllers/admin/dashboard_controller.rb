class Admin::DashboardController < Admin::BaseController
  before_action :require_internal_admin_for_dashboard!, only: :index

  def index
    if current_user&.company_master_admin?
      render :company_master_admin
      return
    end

    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    @document_file_health = DocumentFileHealthCheck.new.call
    @model_browser_entries = Admin::ModelBrowserCatalog.entries.first(8)
    @operational_failure_summary = operational_failure_summary
  end

  private

  def operational_failure_summary
    git_failed_count = GitImportRun.failed.count
    git_skipped_count = GitImportRun.skipped.count
    generated_run_failed_count = GeneratedFileRun.failed.count
    generated_event_failed_count = GeneratedFileEvent.failed.count
    webhook_failed_count = WebhookDelivery.failed.count
    external_sync_failed_count = ExternalFolderSyncRun.failed.count
    external_sync_partial_count = ExternalFolderSyncRun.partial.count

    [
      {
        label: "Git同期",
        count: git_failed_count + git_skipped_count,
        scope: "保存済み履歴の failed / skipped 件数",
        details: ["failed: #{git_failed_count}", "skipped: #{git_skipped_count}"],
        primary_link: ["Git同期履歴を確認", admin_git_import_runs_path]
      },
      {
        label: "生成ファイル",
        count: generated_run_failed_count + generated_event_failed_count,
        scope: "保存済み実行履歴とイベント履歴の failed 件数",
        details: ["実行履歴 failed: #{generated_run_failed_count}", "イベント failed: #{generated_event_failed_count}"],
        primary_link: ["生成実行履歴を確認", admin_generated_file_runs_path(status: "failed")],
        secondary_link: ["生成イベント履歴", admin_generated_file_events_path(status: "failed")]
      },
      {
        label: "Webhook送信",
        count: webhook_failed_count,
        scope: "保存済み送信履歴の failed 件数",
        details: ["failed: #{webhook_failed_count}"],
        primary_link: ["Webhook送信履歴を確認", admin_webhook_deliveries_path(status: "failed")]
      },
      {
        label: "外部フォルダ同期",
        count: external_sync_failed_count + external_sync_partial_count,
        scope: "保存済み同期履歴の failed / partial 件数",
        details: ["failed: #{external_sync_failed_count}", "partial: #{external_sync_partial_count}"],
        primary_link: ["外部フォルダ同期設定を確認", admin_external_folder_sync_sources_path(review: "errors")]
      }
    ]
  end

  def require_internal_admin_for_dashboard!
    return if current_user&.company_master_admin?

    require_admin_only!
  end
end
