# frozen_string_literal: true

module Admin::ProjectsHelper
  def project_table_columns
    [
      table_preferences_column(:code, label: "案件コード", default_width: 150, overflow: :ellipsis, pinned: true),
      table_preferences_column(:name, label: "案件名"),
      table_preferences_column(:company, label: "会社", overflow: :ellipsis),
      table_preferences_column(:description, label: "説明", default_visible: false, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 80),
      table_preferences_column(:actions, label: "操作", default_width: 100, pinned: true)
    ]
  end

  def admin_project_filter_labels(filters, selected_company = nil)
    filters = filters.to_h
    labels = []
    query = filters["q"].to_s.strip
    labels << "検索: #{query}" if query.present?

    case filters["active"].to_s
    when "true"
      labels << "状態: 有効"
    when "false"
      labels << "状態: 無効"
    end

    company_id = filters["company_id"].to_s
    if company_id == "none"
      labels << "会社: 会社未設定"
    elsif company_id.match?(/\A\d+\z/) && selected_company.present?
      labels << "会社: #{selected_company.display_name}"
    end

    labels
  end

  def admin_project_company_filter_collection(selected_company, selected_company_filter)
    options = [["会社未設定", "none"]]
    return options unless selected_company_filter.to_s.match?(/\A\d+\z/) && selected_company.present?

    options + [[admin_project_company_option_label(selected_company), selected_company.id]]
  end

  def admin_project_company_filter_selected_option(selected_company, selected_company_filter)
    return { value: "none", text: "会社未設定" } if selected_company_filter.to_s == "none"

    admin_project_company_selected_option(selected_company)
  end

  def admin_project_company_selected_option(company)
    return if company.blank?

    { value: company.id, text: admin_project_company_option_label(company) }
  end

  def admin_project_company_option_label(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?
    label
  end
end
