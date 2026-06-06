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
    query = filters[:q].to_s.strip
    labels << "検索: #{query}" if query.present?

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

  def document_set_version_usage_label(document_set)
    items = document_set.document_set_items
    fixed_count = items.count { _1.document_version_id.present? }

    return "文書なし" if items.empty?
    return "固定版あり（#{fixed_count}件）" if fixed_count.positive?

    "最新版のみ"
  end

  def document_set_selected_items(document_set, item_params = params[:document_set_items])
    persisted_items = document_set.document_set_items.index_by(&:document_id)
    return persisted_items if item_params.blank? || document_set.project.blank?

    item_rows = item_params.respond_to?(:to_unsafe_h) ? item_params.to_unsafe_h.values : item_params.to_h.values

    item_rows.filter_map do |row|
      next unless ActiveModel::Type::Boolean.new.cast(row[:selected] || row["selected"])

      document_id = row[:document_id] || row["document_id"]
      document = document_set.project.documents.find_by(id: document_id)
      next if document.blank?

      version_id = row[:document_version_id] || row["document_version_id"]
      version = document.document_versions.find_by(id: version_id) if version_id.present?
      item = DocumentSetItem.new(
        document: document,
        document_version: version,
        sort_order: (row[:sort_order] || row["sort_order"]).presence || 0,
        note: (row[:note] || row["note"]).to_s
      )

      [document.id, item]
    end.to_h
  end

  def document_set_remote_document_picker_html_options(project_id)
    {
      id: "document-set-remote-document-picker",
      include_blank: true,
      data: {
        controller: "rails-fields-kit--tom-select",
        rails_fields_kit__tom_select_kind_value: "combobox",
        rails_fields_kit__tom_select_url_value: document_search_admin_document_sets_path(project_id: project_id),
        rails_fields_kit__tom_select_query_param_value: "q",
        rails_fields_kit__tom_select_value_field_value: "id",
        rails_fields_kit__tom_select_label_field_value: "title",
        rails_fields_kit__tom_select_option_description_field_value: "slug",
        rails_fields_kit__tom_select_placeholder_value: "文書名またはURL識別子で検索",
        rails_fields_kit__tom_select_min_length_value: 1,
        rails_fields_kit__tom_select_max_options_value: 20,
        action: "change->document-set-document-filter#pickRemoteDocument rails-fields-kit--tom-select:change->document-set-document-filter#pickRemoteDocument"
      }
    }
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
