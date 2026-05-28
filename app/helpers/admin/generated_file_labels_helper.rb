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

  def generated_file_event_status_label(status)
    EVENT_STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  def generated_file_run_status_label(status)
    RUN_STATUS_LABELS.fetch(status.to_s, status.to_s)
  end

  def generated_file_operation_label(operation)
    OPERATION_LABELS.fetch(operation.to_s, operation.to_s)
  end
end
