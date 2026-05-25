# frozen_string_literal: true

module Admin::DocumentsHelper
  def document_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:title, label: "文書名", default_width: 260, overflow: :ellipsis, sortable: true),
      table_preferences_column(:slug, label: "URL識別子", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:category, label: "カテゴリ", default_width: 140),
      table_preferences_column(:document_kind, label: "種別", default_width: 120),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 140),
      table_preferences_column(:status, label: "状態", default_width: 170),
      table_preferences_column(:retention_until, label: "保管期限", default_width: 120),
      table_preferences_column(:discard_candidate_at, label: "廃棄候補", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 180, pinned: true)
    ]
  end
end
