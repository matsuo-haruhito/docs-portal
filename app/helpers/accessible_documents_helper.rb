# frozen_string_literal: true

module AccessibleDocumentsHelper
  def accessible_document_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 180, pinned: true, overflow: :ellipsis),
      table_preferences_column(:document, label: "文書名", default_width: 240, pinned: true, overflow: :ellipsis),
      table_preferences_column(:match_reason, label: "ヒット理由", default_width: 240, overflow: :ellipsis),
      table_preferences_column(:tags, label: "タグ", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:category, label: "カテゴリ", default_width: 120),
      table_preferences_column(:document_kind, label: "ファイル種", default_width: 120),
      table_preferences_column(:importance_level, label: "重要度", default_width: 120),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 140),
      table_preferences_column(:latest_version, label: "最新版", default_width: 120),
      table_preferences_column(:html, label: "HTML", default_width: 100),
      table_preferences_column(:files, label: "添付", default_width: 100),
      table_preferences_column(:updated_at, label: "最終更新", default_width: 160, sortable: true)
    ]
  end
end
