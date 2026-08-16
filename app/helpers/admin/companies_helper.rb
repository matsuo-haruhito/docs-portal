# frozen_string_literal: true

module Admin::CompaniesHelper
  def admin_company_table_columns
    [
      table_preferences_column(:domain, label: "ドメイン", overflow: :ellipsis, pinned: true),
      table_preferences_column(:name, label: "会社名（表示用）", overflow: :ellipsis),
      table_preferences_column(:display_name, label: "表示名", overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 80),
      table_preferences_column(:actions, label: "操作", default_width: 100, pinned: true)
    ]
  end
end
