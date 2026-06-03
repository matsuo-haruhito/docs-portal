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
    @operation_failure_summaries = operation_failure_summaries
  end

  private

  def require_internal_admin_for_dashboard!
    return if current_user&.company_master_admin?

    require_admin_only!
  end

  def operation_failure_summaries
    [
      {
        title: "Git同期履歴",
        count: GitImportRun.where(status: %i[failed skipped]).count,
        count_label: "失敗/スキップ",
        scope_label: "保存済み履歴全体",
        path: admin_git_import_runs_path,
        description: "Git取り込みの失敗やスキップを確認します。"
      },
      {
        title: "生成ファイルイベント",
        count: GeneratedFileEvent.failed.count,
        count_label: "失敗",
        scope_label: "保存済みイベント全体",
        path: admin_generated_file_events_path(status: "failed"),
        description: "dispatch に失敗した生成イベントを確認します。"
      },
      {
        title: "生成ファイル実行履歴",
        count: GeneratedFileRun.failed.count,
        count_label: "失敗",
        scope_label: "保存済み実行履歴全体",
        path: admin_generated_file_runs_path(status: "failed"),
        description: "生成ジョブの失敗履歴と再実行入口を確認します。"
      },
      {
        title: "Webhook送信履歴",
        count: WebhookDelivery.failed.count,
        count_label: "失敗",
        scope_label: "保存済み送信履歴全体",
        path: admin_webhook_deliveries_path(status: "failed"),
        description: "Webhook delivery の失敗と再送可否を確認します。"
      },
      {
        title: "外部フォルダ同期",
        count: external_folder_sync_attention_count,
        count_label: "要確認",
        scope_label: "設定ごとの最新run/保存エラー",
        path: admin_external_folder_sync_sources_path,
        description: "最新同期の失敗・警告や保存済みエラーを確認します。"
      }
    ]
  end

  def external_folder_sync_attention_count
    sources = ExternalFolderSyncSource.select(:id, :last_error_message).to_a
    return 0 if sources.empty?

    latest_runs_by_source_id = ExternalFolderSyncRun
      .where(external_folder_sync_source_id: sources.map(&:id))
      .order(started_at: :desc, id: :desc)
      .group_by(&:external_folder_sync_source_id)
      .transform_values(&:first)

    sources.count do |source|
      latest_run = latest_runs_by_source_id[source.id]
      source.last_error_message.present? ||
        latest_run&.failed? ||
        latest_run&.partial? ||
        latest_run_conflict_warnings_count(latest_run).positive?
    end
  end

  def latest_run_conflict_warnings_count(run)
    return 0 unless run

    run.summary_json.to_h.fetch("conflict_warnings_count", 0).to_i
  end
end
