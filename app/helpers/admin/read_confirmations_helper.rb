# frozen_string_literal: true

module Admin::ReadConfirmationsHelper
  def read_confirmation_table_columns
    [
      table_preferences_column(:confirmed_at, label: "確認日時", default_width: 170, pinned: true, sortable: true),
      table_preferences_column(:document, label: "文書", default_width: 220, pinned: true, overflow: :ellipsis),
      table_preferences_column(:user, label: "確認者", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:company, label: "会社", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:document_slug, label: "文書URL識別子", default_width: 170, overflow: :ellipsis)
    ]
  end

  def read_confirmation_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def read_confirmation_project_selected_option(project)
    return if project.blank?

    { value: project.id, text: read_confirmation_project_option_label(project) }
  end

  def read_confirmation_company_selected_option(company)
    return if company.blank?

    { value: company.id, text: company.display_name }
  end

  def read_confirmation_user_selected_option(user)
    return if user.blank?

    { value: user.id, text: [user.display_name, user.email_address, user.company&.display_name].compact_blank.join(" / ") }
  end
end
