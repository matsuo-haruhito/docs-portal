class Admin::DashboardController < Admin::BaseController
  OPERATIONAL_FAILURE_STALE_THRESHOLD = 7.days

  before_action :require_internal_admin_for_dashboard!, only: :index

  def index
    if current_user&.company_master_admin?
      render :company_master_admin
      return
    end

    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    @document_file_health = DocumentFileHealthCheck.new.call
    @storage_usage_summary = StorageUsageSummary.new.call
    @model_browser_entries = Admin::ModelBrowserCatalog.entries.first(8)
    @model_browser_entry_summaries = @model_browser_entries.index_with { Admin::ModelBrowserSummary.for(_1) }
    @operational_failure_summary = operational_failure_summary
  end

  private

  def operational_failure_summary
    git_failed_runs = GitImportRun.failed
    git_skipped_runs = GitImportRun.skipped
    generated_failed_runs = GeneratedFileRun.failed
    generated_failed_events = GeneratedFileEvent.failed
    failed_webhook_deliveries = WebhookDelivery.failed
    failed_external_sync_runs = ExternalFolderSyncRun.failed
    partial_external_sync_runs = ExternalFolderSyncRun.partial

    git_failed_count = git_failed_runs.count
    git_skipped_count = git_skipped_runs.count
    generated_run_failed_count = generated_failed_runs.count
    generated_event_failed_count = generated_failed_events.count
    webhook_failed_count = failed_webhook_deliveries.count
    external_sync_failed_count = failed_external_sync_runs.count
    external_sync_partial_count = partial_external_sync_runs.count

    [
      {
        label: "Git同期",
        count: git_failed_count + git_skipped_count,
        scope: "保存済み履歴の failed / skipped 件数",
        details: ["failed: #{git_failed_count}", "skipped: #{git_skipped_count}"],
        latest_at: latest_operational_failure_at(git_failed_runs, git_skipped_runs),
        primary_link: ["Git同期履歴を確認", admin_git_import_runs_path]
      },
      {
        label: "生成ファイル",
        count: generated_run_failed_count + generated_event_failed_count,
        scope: "保存済み実行履歴とイベント履歴の failed 件数",
        details: ["実行履歴 failed: #{generated_run_failed_count}", "イベント failed: #{generated_event_failed_count}"],
        latest_at: latest_operational_failure_at(generated_failed_runs, generated_failed_events),
        primary_link: ["生成実行履歴を確認", admin_generated_file_runs_path(status: "failed")],
        secondary_link: ["生成イベント履歴", admin_generated_file_events_path(status: "failed")]
      },
      {
        label: "Webhook送信",
        count: webhook_failed_count,
        scope: "保存済み送信履歴の failed 件数",
        details: ["failed: #{webhook_failed_count}"],
        latest_at: latest_operational_failure_at(failed_webhook_deliveries),
        primary_link: ["Webhook送信履歴を確認", admin_webhook_deliveries_path(status: "failed")]
      },
      {
        label: "外部フォルダ同期",
        count: external_sync_failed_count + external_sync_partial_count,
        scope: "保存済み同期履歴の failed / partial 件数",
        details: ["failed: #{external_sync_failed_count}", "partial: #{external_sync_partial_count}"],
        latest_at: latest_operational_failure_at(failed_external_sync_runs, partial_external_sync_runs),
        primary_link: ["外部フォルダ同期設定を確認", admin_external_folder_sync_sources_path(review: "errors")]
      }
    ].map do |item|
      item.merge(stale: operational_failure_stale?(item[:latest_at]))
    end
  end

  def latest_operational_failure_at(*relations)
    relations.filter_map { |relation| relation.maximum(:updated_at) }.max
  end

  def operational_failure_stale?(latest_at)
    latest_at.present? && latest_at < OPERATIONAL_FAILURE_STALE_THRESHOLD.ago
  end

  def require_internal_admin_for_dashboard!
    return if current_user&.company_master_admin?

    require_admin_only!
  end
end
