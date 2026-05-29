# frozen_string_literal: true

module Admin::ExternalFolderSyncSourcesHelper
  def external_folder_sync_source_table_columns
    [
      table_preferences_column(:project, label: "対象案件", default_width: 220, pinned: true, overflow: :ellipsis),
      table_preferences_column(:name, label: "同期設定名", default_width: 220, overflow: :ellipsis, sortable: true),
      table_preferences_column(:provider, label: "連携先", default_width: 170),
      table_preferences_column(:external_folder_location, label: "外部フォルダID / path", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:status, label: "同期状態", default_width: 110),
      table_preferences_column(:last_synced_at, label: "最終同期日時", default_width: 180, sortable: true),
      table_preferences_column(:latest_safety, label: "最新安全判定", default_width: 150),
      table_preferences_column(:warning_count, label: "競合・重複警告", default_width: 140),
      table_preferences_column(:latest_error, label: "最新エラー", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:actions, label: "操作", default_width: 230, pinned: true)
    ]
  end
end
