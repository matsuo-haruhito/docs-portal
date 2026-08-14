# frozen_string_literal: true

module Admin::UsersHelper
  def admin_user_table_columns
    [
      table_preferences_column(:name, label: "登録氏名", default_visible: false, default_width: 180, overflow: :ellipsis),
      table_preferences_column(:email_address, label: "メールアドレス", default_width: 240, overflow: :ellipsis, sortable: true),
      table_preferences_column(:display_name, label: "画面表示名", default_visible: true, default_width: 180, overflow: :ellipsis),
      table_preferences_column(:user_type, label: "種別", default_width: 110),
      table_preferences_column(:company, label: "会社", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 80),
      table_preferences_column(:actions, label: "操作", default_width: 100, pinned: true)
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
