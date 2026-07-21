# frozen_string_literal: true

module Admin::GitImportSourcesHelper
  def git_import_source_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:repository, label: "リポジトリ", default_width: 240, overflow: :ellipsis, sortable: true),
      table_preferences_column(:branch_path, label: "ブランチ/パス", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:auth_type, label: "認証方式", default_width: 180),
      table_preferences_column(:last_synced, label: "最終同期", default_width: 180, pinned: true),
      table_preferences_column(:enabled, label: "状態", default_width: 96, pinned: true),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end

  def git_import_source_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def git_import_source_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: git_import_source_project_option_label(project) }
  end

  def git_import_source_repository_selected_option(repository_full_name)
    return nil if repository_full_name.blank?

    { value: repository_full_name, text: repository_full_name }
  end

  def git_import_source_branch_selected_option(branch)
    return nil if branch.blank?

    { value: branch, text: branch }
  end
end
