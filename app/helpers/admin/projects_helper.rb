# frozen_string_literal: true

module Admin::ProjectsHelper
  def project_table_columns
    [
      table_preferences_column(:code, label: "コード", default_width: 140, pinned: true),
      table_preferences_column(:name, label: "案件名", default_width: 220, sortable: true),
      table_preferences_column(:company, label: "企業", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:description, label: "説明", default_width: 320, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 120),
      table_preferences_column(:actions, label: "操作", default_width: 180, pinned: true)
    ]
  end

  def admin_project_filter_labels(filters, companies)
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
      labels << "企業: 企業未設定"
    elsif company_id.match?(/\A\d+\z/)
      company = companies.find { |candidate| candidate.id.to_s == company_id }
      labels << "企業: #{company.display_name}" if company.present?
    end

    labels
  end
end
