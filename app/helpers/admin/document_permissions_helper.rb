# frozen_string_literal: true

module Admin::DocumentPermissionsHelper
  DOCUMENT_PERMISSION_FORM_BASE_ERROR_MESSAGES = {
    "company_id or user_id is required" => "適用対象は会社かユーザーのどちらか一方を指定してください。",
    "company_id and user_id cannot both be set" => "適用対象は会社かユーザーのどちらか一方だけを指定してください。"
  }.freeze

  DOCUMENT_PERMISSION_TARGET_TYPE_OPTIONS = [
    ["会社単位", "company"],
    ["ユーザー単位", "user"]
  ].freeze

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
    documents.map { [document_permission_form_document_label(_1), _1.id] }
  end

  def document_permission_form_document_selected_option(document)
    return if document.blank?

    { value: document.id, text: document_permission_form_document_label(document) }
  end

  def document_permission_form_document_label(document)
    "#{document.title} / #{document.project.name}"
  end

  def document_permission_filter_project_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def document_permission_filter_project_selected_option(project)
    return if project.blank?

    { value: project.id, text: document_permission_filter_project_label(project) }
  end

  def document_permission_filter_access_level_options
    [["すべて", ""]] + enum_options_for("document_permissions.access_level", DocumentPermission.access_levels.keys)
  end

  def document_permission_filter_target_type_options
    [["すべて", ""]] + DOCUMENT_PERMISSION_TARGET_TYPE_OPTIONS
  end

  def document_permission_target_type_label(value)
    DOCUMENT_PERMISSION_TARGET_TYPE_OPTIONS.to_h.invert.fetch(value, value)
  end

  def document_permission_form_company_options(companies)
    companies.map { [document_permission_form_company_label(_1), _1.id] }
  end

  def document_permission_form_company_selected_option(company)
    return if company.blank?

    { value: company.id, text: document_permission_form_company_label(company) }
  end

  def document_permission_form_company_label(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?
    label
  end

  def document_permission_form_user_options(users)
    users.map { [document_permission_form_user_label(_1), _1.id] }
  end

  def document_permission_form_user_selected_option(user)
    return if user.blank?

    { value: user.id, text: document_permission_form_user_label(user) }
  end

  def document_permission_form_user_label(user)
    primary_label = user.display_name.presence || user.email_address
    primary_label == user.email_address ? primary_label : "#{primary_label} / #{user.email_address}"
  end

  def document_permission_company_primary_label(company)
    company&.display_name.presence || company&.domain
  end

  def document_permission_company_secondary_label(company)
    return if company.blank? || company.display_name.blank? || company.domain.blank?
    return if company.display_name == company.domain

    company.domain
  end

  def document_permission_user_primary_label(user)
    user&.display_name.presence || user&.email_address
  end

  def document_permission_user_secondary_label(user)
    return if user.blank? || user.display_name.blank? || user.email_address.blank?
    return if user.display_name == user.email_address

    user.email_address
  end

  def document_permission_target_error_messages(document_permission)
    document_permission.errors
      .select { |error| error.attribute == :base && DOCUMENT_PERMISSION_FORM_BASE_ERROR_MESSAGES.key?(error.message) }
      .map { |error| DOCUMENT_PERMISSION_FORM_BASE_ERROR_MESSAGES.fetch(error.message) }
      .uniq
  end

  def document_permission_form_error_messages(document_permission)
    document_permission.errors.map do |error|
      if error.attribute == :base
        DOCUMENT_PERMISSION_FORM_BASE_ERROR_MESSAGES.fetch(error.message, error.message)
      else
        document_permission.errors.full_message(error.attribute, error.message)
      end
    end.uniq
  end
end
