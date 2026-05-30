# frozen_string_literal: true

module Admin::AccessLogsHelper
  ACCESS_LOG_TARGET_TYPE_FILTERS = %w[page file zip ai_context].freeze

  def access_log_table_columns
    [
      table_preferences_column(:accessed_at, label: "日時", default_width: 170, pinned: true, sortable: true),
      table_preferences_column(:action_type, label: "操作", default_width: 120),
      table_preferences_column(:target, label: "対象", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:user, label: "ユーザー", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:company, label: "会社", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:project, label: "案件", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:document, label: "文書", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:document_version, label: "版", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:ip_address, label: "IPアドレス", default_width: 150)
    ]
  end

  def access_log_target_type_filter_options
    enum_options_for("access_logs.target_type", ACCESS_LOG_TARGET_TYPE_FILTERS)
  end

  def access_log_filter_select_html_options(placeholder:)
    {
      data: {
        controller: "rails-fields-kit--tom-select",
        rails_fields_kit__tom_select_kind_value: "select",
        rails_fields_kit__tom_select_placeholder_value: placeholder,
        rails_fields_kit__tom_select_plugins_value: ["clear_button"]
      }
    }
  end

  def access_log_project_filter_options(projects)
    projects.map { ["#{_1.code} / #{_1.name}", _1.id] }
  end

  def access_log_company_filter_options(companies)
    companies.map do |company|
      label = company.display_name
      label = "#{label} / #{company.domain}" if company.domain.present?
      [label, company.id]
    end
  end

  def access_log_user_filter_options(users)
    users.map do |user|
      primary_label = user.display_name.presence || user.email_address
      label = primary_label == user.email_address ? primary_label : "#{primary_label} / #{user.email_address}"
      [label, user.id]
    end
  end

  def access_log_company_secondary_label(company)
    return unless company

    domain = company.domain.presence
    return if domain.blank? || company.display_name == domain

    domain
  end

  def access_log_project_secondary_label(project)
    project&.code.presence
  end
end