# frozen_string_literal: true

module Admin::DocumentUsageReportsHelper
  DOCUMENT_USAGE_REPORT_HANDOFF_LIMIT = 5

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

  def document_usage_report_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: document_usage_report_project_option_label(project) }
  end

  def document_usage_report_unused_handoff_digest(report_hash:, project:, from_date:, to_date:, query:, sort_order:)
    rows = report_hash[:documents].first(DOCUMENT_USAGE_REPORT_HANDOFF_LIMIT)
    lines = [
      "# 未利用文書 handoff",
      "",
      "## 現在条件",
      "- 案件: #{document_usage_report_project_option_label(project)}",
      "- 期間: #{document_usage_report_period_label(from_date, to_date)}",
      "- 利用状況: #{document_usage_report_filter_label('unused')}",
      "- 並び順: #{document_usage_report_sort_label(sort_order)}",
      "- 検索: #{query.presence || 'なし'}",
      "",
      "## 件数",
      "- 表示中の未利用文書: #{report_hash[:documents].size}件",
      "- 案件全体の未利用文書: #{report_hash.dig(:summary, :unused_document_count)}件",
      "- 代表行: 先頭#{rows.size}件",
      "",
      "## 代表文書"
    ]

    if rows.any?
      rows.each.with_index(1) do |row, index|
        lines.concat(document_usage_report_unused_handoff_row_lines(row, index))
      end
    else
      lines << "- なし"
    end

    lines.concat([
      "",
      "## 注意",
      "- 未利用は現在期間内の閲覧・ダウンロード・既読確認がない候補であり、不要・削除・archive 確定ではありません。",
      "- この digest は read-only の確認依頼用です。bulk action、retention policy、CSV format、集計定義は変更しません。",
      "- 代表文書は表示中の先頭#{DOCUMENT_USAGE_REPORT_HANDOFF_LIMIT}件までです。全件 export は既存 CSV を確認してください。"
    ])

    lines.join("\n")
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

  def document_usage_report_empty_state_heading(report_hash:, usage_filter:, query:)
    return "この案件には文書がありません" if report_hash.dig(:summary, :document_count).to_i.zero?
    return "期間内に未利用候補はありません" if usage_filter == "unused"
    return "利用ありの文書はありません" if usage_filter == "used"
    return "検索語に一致する文書はありません" if query.present?

    "条件に一致する文書はありません"
  end

  def document_usage_report_empty_state_body(report_hash:, usage_filter:, query:)
    return "案件に文書が追加されると、利用状況、既読確認、監査ログへの入口をここで確認できます。" if report_hash.dig(:summary, :document_count).to_i.zero?

    case usage_filter
    when "unused"
      "現在の条件では、期間内に閲覧・DL・既読確認がない文書はありません。未利用は削除・archive確定ではなく、現在条件でsignalがない候補です。"
    when "used"
      "現在の条件では、閲覧・DL・既読確認のいずれかがある文書はありません。検索語、期間、利用状況filterを見直してください。"
    else
      if query.present?
        "文書名または slug が検索語に一致する文書はありません。検索語を短くするか、条件をクリアして案件全体を確認してください。"
      else
        "検索語、期間、利用状況filterを変えるか、条件をクリアして案件全体を確認してください。"
      end
    end
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
      "期間内の閲覧・DL・既読確認なし（期間外の実績は含みません） / 削除・archive確定ではありません"
    when :read_confirmation_only
      "閲覧・DLはなく、既読確認の内訳を確認（閲覧・downloadはありません）"
    end
  end

  private

  def document_usage_report_unused_handoff_row_lines(row, index)
    [
      "#{index}. #{row[:title]}",
      "   - slug: #{row[:slug]}",
      "   - カテゴリ: #{document_category_label(row[:category])}",
      "   - 種別: #{document_kind_label(row[:document_kind])}",
      "   - 公開範囲: #{document_visibility_policy_label(row[:visibility_policy])}",
      "   - 最終アクセス: #{row[:last_accessed_at].presence || '-'}"
    ]
  end
end
