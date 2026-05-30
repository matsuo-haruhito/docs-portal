# frozen_string_literal: true

module Admin::DocumentSetsHelper
  def document_set_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:name, label: "名称", default_width: 240, overflow: :ellipsis, sortable: true),
      table_preferences_column(:set_type, label: "種別", default_width: 140, filter: { type: :select, param: :set_type }),
      table_preferences_column(:visibility_policy, label: "公開範囲", default_width: 160, filter: { type: :select, param: :visibility_policy }),
      table_preferences_column(:documents_count, label: "文書数", default_width: 96),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end

  def admin_document_set_type_filter_options
    [["すべて", ""]] + DocumentSet.set_types.keys.map { |key| [document_set_type_label(key), key] }
  end

  def admin_document_set_visibility_filter_options
    [["すべて", ""]] + DocumentSet.visibility_policies.keys.map { |key| [document_set_visibility_policy_label(key), key] }
  end

  def admin_document_set_filter_labels(filters)
    filters = filters.to_h.symbolize_keys
    labels = []

    if DocumentSet.set_types.key?(filters[:set_type].to_s)
      labels << "種別: #{document_set_type_label(filters[:set_type])}"
    end

    if DocumentSet.visibility_policies.key?(filters[:visibility_policy].to_s)
      labels << "公開範囲: #{document_set_visibility_policy_label(filters[:visibility_policy])}"
    end

    labels
  end

  def admin_document_set_filters_active?(filters)
    admin_document_set_filter_labels(filters).any?
  end

  def document_set_version_select_html_options(placeholder: "固定する版を検索")
    {
      data: {
        controller: "rails-fields-kit--tom-select",
        rails_fields_kit__tom_select_kind_value: "select",
        rails_fields_kit__tom_select_placeholder_value: placeholder,
        rails_fields_kit__tom_select_plugins_value: ["clear_button"]
      }
    }
  end
end
