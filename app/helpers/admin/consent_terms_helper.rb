# frozen_string_literal: true

module Admin::ConsentTermsHelper
  def consent_term_table_columns
    [
      table_preferences_column(:title, label: "タイトル", default_width: 280, pinned: true, overflow: :ellipsis, sortable: true),
      table_preferences_column(:version_label, label: "版", default_width: 120, sortable: true),
      table_preferences_column(:consent_scope, label: "種別", default_width: 160),
      table_preferences_column(:requirement_timing, label: "再同意方針", default_width: 180),
      table_preferences_column(:status, label: "状態", default_width: 100),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end

  def consent_term_filter_summary(filters, result_count:, display_start: nil, display_end: nil)
    conditions = consent_term_filter_summary_conditions(filters)
    count_label = consent_term_result_count_label(
      result_count:,
      display_start:,
      display_end:
    )

    return count_label if conditions.blank?

    "#{count_label}（#{conditions.join(' / ')}）"
  end

  def consent_term_status_label(term)
    term.active? ? "利用中" : "無効化済み"
  end

  private

  def consent_term_result_count_label(result_count:, display_start:, display_end:)
    return "表示中: #{result_count}件" if display_start.blank? || display_end.blank?

    "条件に一致する同意文面 #{result_count}件中 #{display_start}-#{display_end}件を表示"
  end

  def consent_term_filter_summary_conditions(filters)
    filters = filters.to_h.symbolize_keys
    conditions = []

    query = filters[:q].to_s.strip
    conditions << "検索: #{query}" if query.present?

    case filters[:active]
    when "true"
      conditions << "状態: 有効"
    when "false"
      conditions << "状態: 無効"
    end

    if ConsentTerm.consent_scopes.key?(filters[:consent_scope])
      conditions << "種別: #{localized_label('consent_terms.consent_scope', filters[:consent_scope])}"
    end

    if ConsentTerm.requirement_timings.key?(filters[:requirement_timing])
      conditions << "再同意方針: #{localized_label('consent_terms.requirement_timing', filters[:requirement_timing])}"
    end

    conditions
  end
end
