# frozen_string_literal: true

module Admin::ProjectMembershipsHelper
  def project_membership_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:user, label: "ユーザー", default_width: 260, overflow: :ellipsis, sortable: true),
      table_preferences_column(:role, label: "権限", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end

  def project_membership_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def project_membership_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: project_membership_project_option_label(project) }
  end

  def project_membership_user_option_label(user)
    [user.display_name, user.email_address].compact_blank.join(" / ")
  end

  def project_membership_user_selected_option(user)
    return nil if user.blank?

    { value: user.id, text: project_membership_user_option_label(user) }
  end
end
