# frozen_string_literal: true

module Admin::UsersHelper
  def admin_user_table_columns
    [
      table_preferences_column(:name, label: "ユーザー名（表示用）", default_width: 200, overflow: :ellipsis),
      table_preferences_column(:email_address, label: "メールアドレス", default_width: 260, overflow: :ellipsis, sortable: true),
      table_preferences_column(:display_name, label: "表示名", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:user_type, label: "種別", default_width: 140),
      table_preferences_column(:company, label: "会社", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 180, pinned: true)
    ]
  end

  def admin_user_company_selected_option(company)
    return if company.blank?

    { value: company.id, text: admin_user_company_label(company) }
  end

  def admin_user_company_label(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?
    label
  end
end
