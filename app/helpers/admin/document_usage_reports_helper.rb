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

  def document_usage_report_filter_options
    [["すべて", "all"], ["利用あり", "used"], ["未利用", "unused"]]
  end

  def document_usage_report_filter_label(value)
    document_usage_report_filter_options.to_h.invert.fetch(value, "すべて")
  end

  def document_usage_report_sort_options
    [["タイトル順", "title"], ["最終アクセスが新しい順", "last_accessed_desc"], ["最終アクセスが古い順", "last_accessed_asc"]]
  end

  def document_usage_report_sort_label(value)
    document_usage_report_sort_options.to_h.invert.fetch(value, "タイトル順")
  end
end
