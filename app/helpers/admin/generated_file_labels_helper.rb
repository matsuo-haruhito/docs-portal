module Admin::GeneratedFileLabelsHelper
  EVENT_STATUS_LABELS = {
    "pending" => "未処理",
    "processing" => "処理中",
    "processed" => "処理済み",
    "failed" => "失敗"
  }.freeze

  RUN_STATUS_LABELS = {
    "running" => "実行中",
    "completed" => "完了",
    "failed" => "失敗",
    "skipped" => "スキップ"
  }.freeze

  OPERATION_LABELS = {
    "create" => "作成",
    "update" => "更新",
    "delete" => "削除"
  }.freeze

  SOURCE_LABELS = {
    "manual_document_upload" => "文書手動アップロード",
    "artifact_import" => "ZIP / APIインポート",
    "generated_file_run_retry" => "生成ジョブからの再実行",
    "generated_file_run_bulk_retry" => "生成ジョブからの一括再実行",
    "scheduled_sync" => "定期同期",
    "spec" => "テスト"
  }.freeze

  SOURCE_BADGE_LABELS = {
    "generated_file_run_retry" => "再実行",
    "generated_file_run_bulk_retry" => "一括再実行"
  }.freeze

  def generated_file_event_table_columns
    [
      table_preferences_column(:public_id, label: "イベントID", default_width: 160, pinned: true, sortable: true),
      table_preferences_column(:status, label: "状態", default_width: 110, pinned: true),
      table_preferences_column(:path, label: "パス", default_width: 320, overflow: :ellipsis, sortable: true),
      table_preferences_column(:operation, label: "操作種別", default_width: 120),
      table_preferences_column(:event_source, label: "発生元", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:error_message, label: "エラー", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:occurrences_count, label: "回数", default_width: 90),
      table_preferences_column(:scheduled_at, label: "実行予定", default_width: 180, sortable: true),
      table_preferences_column(:processed_at, label: "処理完了", default_width: 180, sortable: true),
      table_preferences_column(:actions, label: "操作", default_width: 160, pinned: true)
    ]
  end

  def generated_file_run_table_columns
    [
      table_preferences_column(:public_id, label: "実行ID", default_width: 160, pinned: true, sortable: true),
      table_preferences_column(:status, label: "状態", default_width: 110, pinned: true),
      table_preferences_column(:job_id, label: "ジョブ", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:generator, label: "ジェネレーター", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:output_writer, label: "出力先", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:event_source, label: "イベント発生元", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:started_at, label: "開始", default_width: 180, sortable: true),
      table_preferences_column(:finished_at, label: "終了", default_width: 180, sortable: true),
      table_preferences_column(:actions, label: "操作", default_width: 160, pinned: true)
    ]
  end

  def generated_file_event_status_label(status)
    EVENT_STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  def generated_file_run_status_label(status)
    RUN_STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  def generated_file_operation_label(operation)
    OPERATION_LABELS.fetch(operation.to_s, operation.to_s)
  end

  def generated_file_source_label(event_source)
    value = event_source.to_s
    return "-" if value.blank?

    SOURCE_LABELS.fetch(value, value.humanize)
  end

  def generated_file_source_badge_label(event_source)
    SOURCE_BADGE_LABELS[event_source.to_s]
  end
end
