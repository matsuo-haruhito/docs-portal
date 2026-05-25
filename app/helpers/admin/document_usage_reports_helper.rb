# frozen_string_literal: true

module Admin::DocumentUsageReportsHelper
  def document_usage_report_table_columns
    [
      table_preferences_column(:title, label: "文書名", default_width: 280, pinned: true, overflow: :ellipsis),
      table_preferences_column(:category, label: "カテゴリ", default_width: 140),
      table_preferences_column(:document_kind, label: "種別", default_width: 140),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 160),
      table_preferences_column(:used, label: "利用", default_width: 88),
      table_preferences_column(:view_count, label: "閲覧", default_width: 88),
      table_preferences_column(:download_count, label: "ダウンロード", default_width: 120),
      table_preferences_column(:read_confirmation_count, label: "既読確認", default_width: 120),
      table_preferences_column(:last_accessed_at, label: "最終アクセス", default_width: 180)
    ]
  end

  def document_usage_report_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end
end
