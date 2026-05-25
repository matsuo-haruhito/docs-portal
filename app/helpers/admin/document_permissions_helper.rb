# frozen_string_literal: true

module Admin::DocumentPermissionsHelper
  def document_permission_overview_table_columns
    [
      table_preferences_column(:document, label: "文書名", default_width: 260, pinned: true, overflow: :ellipsis, sortable: true),
      table_preferences_column(:project, label: "案件", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 140),
      table_preferences_column(:company_permissions, label: "会社権限", default_width: 100),
      table_preferences_column(:user_permissions, label: "ユーザー権限", default_width: 110),
      table_preferences_column(:view_allowed, label: "閲覧", default_width: 90),
      table_preferences_column(:download_allowed, label: "ダウンロード", default_width: 110)
    ]
  end

  def document_permissions_table_columns
    [
      table_preferences_column(:document, label: "文書名", default_width: 260, pinned: true, overflow: :ellipsis, sortable: true),
      table_preferences_column(:company, label: "会社", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:user, label: "ユーザー", default_width: 240, overflow: :ellipsis),
      table_preferences_column(:access_level, label: "権限", default_width: 110),
      table_preferences_column(:actions, label: "操作", default_width: 140, pinned: true)
    ]
  end

  def document_permission_form_document_options(documents)
    documents.map { ["#{_1.title} / #{_1.project.name}", _1.id] }
  end

  def document_permission_form_company_options(companies)
    companies.map do |company|
      label = company.display_name
      label = "#{label} / #{company.domain}" if company.domain.present?
      [label, company.id]
    end
  end

  def document_permission_form_user_options(users)
    users.map do |user|
      primary_label = user.display_name.presence || user.email_address
      label = primary_label == user.email_address ? primary_label : "#{primary_label} / #{user.email_address}"
      [label, user.id]
    end
  end
end
