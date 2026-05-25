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

  def consent_term_status_label(term)
    term.active? ? "有効" : "無効"
  end
end
