# frozen_string_literal: true

module Admin::DocumentUsageReportsHelper
  def document_usage_report_table_columns
    [
      table_preferences_column(:title, label: "文書名", default_width: 280, pinned: true, overflow: :ellipsis),
      table_preferences_column(:category, label: "カテゴリ", default_width: 140),
      table_preferences_column(:document_kind, label: "種別", default_width: 140),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 160),
      table_preferences_column(:used, label: "利用", default_width: 120),
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

  def document_usage_report_period_label(from_date, to_date)
    case [from_date.present?, to_date.present?]
    when [true, true]
      "#{from_date.iso8601} から #{to_date.iso8601} まで"
    when [true, false]
      "#{from_date.iso8601} 以降"
    when [false, true]
      "#{to_date.iso8601} まで"
    else
      "指定なし（案件全体の累積）"
    end
  end

  def document_usage_report_ignored_date_filter_label(names)
    labels = { from: "開始日", to: "終了日" }

    Array(names).map { labels.fetch(_1, _1.to_s) }.join(" / ")
  end

  def document_usage_report_usage_state(row)
    return :unused unless row[:used]

    if row[:view_count].to_i.zero? && row[:download_count].to_i.zero? && row[:read_confirmation_count].to_i.positive?
      :read_confirmation_only
    else
      :used
    end
  end

  def document_usage_report_usage_badge_label(row)
    case document_usage_report_usage_state(row)
    when :unused
      "未利用"
    when :read_confirmation_only
      "既読のみ"
    else
      "利用あり"
    end
  end

  def document_usage_report_usage_badge_class(row)
    base_class = "inline-flex rounded px-2 py-1 text-xs font-semibold"

    state_class = case document_usage_report_usage_state(row)
                  when :unused
                    "bg-gray-100 text-gray-700"
                  when :read_confirmation_only
                    "bg-amber-100 text-amber-800"
                  else
                    "bg-green-100 text-green-800"
                  end

    "#{base_class} #{state_class}"
  end

  def document_usage_report_usage_hint(row)
    case document_usage_report_usage_state(row)
    when :unused
      "期間内の閲覧・DL・既読確認なし"
    when :read_confirmation_only
      "既読確認の内訳を確認"
    end
  end
end
