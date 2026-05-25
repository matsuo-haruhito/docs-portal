# frozen_string_literal: true

module Admin::GitImportRunsHelper
  def git_import_run_table_columns
    [
      table_preferences_column(:created_at, label: "実行日時", default_width: 180, pinned: true, sortable: true),
      table_preferences_column(:project, label: "案件", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:repository, label: "リポジトリ", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:branch_path, label: "ブランチ/パス", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:commit_sha, label: "コミット", default_width: 140),
      table_preferences_column(:status, label: "状態", default_width: 110, pinned: true),
      table_preferences_column(:summary, label: "実行結果", default_width: 340),
      table_preferences_column(:error_message, label: "エラー", default_width: 340)
    ]
  end
end
