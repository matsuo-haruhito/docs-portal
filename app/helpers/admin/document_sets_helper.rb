# frozen_string_literal: true

module Admin::DocumentSetsHelper
  def document_set_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:name, label: "名称", default_width: 240, overflow: :ellipsis, sortable: true),
      table_preferences_column(:set_type, label: "種別", default_width: 140, filter: { type: :select, param: :set_type }),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 160, filter: { type: :select, param: :visibility_policy }),
      table_preferences_column(:documents_count, label: "文書数", default_width: 96),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end
end
