# frozen_string_literal: true

module Admin::ProjectsHelper
  def project_table_columns
    [
      table_preferences_column(:code, label: "コード", default_width: 140, pinned: true),
      table_preferences_column(:name, label: "案件名", default_width: 220, sortable: true),
      table_preferences_column(:company, label: "企業", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:description, label: "説明", default_width: 320, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 180, pinned: true)
    ]
  end
end
