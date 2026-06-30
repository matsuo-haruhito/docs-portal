# frozen_string_literal: true

module Admin::DocumentCatalogsHelper
  def document_catalog_audience_type_label(value)
    localized_label("document_catalogs.audience_type", value)
  end

  def document_catalog_visibility_policy_label(value)
    localized_label("document_catalogs.visibility_policy", value)
  end

  def document_catalog_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def document_catalog_project_options(projects)
    projects.map { |project| [document_catalog_project_option_label(project), project.id] }
  end

  def document_catalog_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: document_catalog_project_option_label(project) }
  end

  def document_catalog_selected_items(document_catalog, item_params = params[:document_catalog_items])
    persisted_items = document_catalog.document_catalog_items.index_by(&:document_id)
    return persisted_items if item_params.blank? || document_catalog.project.blank?

    item_rows = item_params.respond_to?(:to_unsafe_h) ? item_params.to_unsafe_h.values : item_params.to_h.values

    item_rows.filter_map do |row|
      next unless ActiveModel::Type::Boolean.new.cast(row[:selected] || row["selected"])

      document_id = row[:document_id] || row["document_id"]
      document = document_catalog.project.documents.find_by(id: document_id)
      next if document.blank?

      item = DocumentCatalogItem.new(
        document: document,
        sort_order: (row[:sort_order] || row["sort_order"]).presence || 0,
        note: (row[:note] || row["note"]).to_s
      )

      [document.id, item]
    end.to_h
  end

  def document_catalog_remote_document_picker_html_options(project_id)
    {
      id: "document-catalog-remote-document-picker",
      include_blank: true,
      data: {
        controller: "rails-fields-kit--tom-select",
        rails_fields_kit__tom_select_kind_value: "combobox",
        rails_fields_kit__tom_select_url_value: document_search_admin_document_catalogs_path(project_id: project_id),
        rails_fields_kit__tom_select_selected_url_value: selected_document_admin_document_catalogs_path(project_id: project_id),
        rails_fields_kit__tom_select_query_param_value: "q",
        rails_fields_kit__tom_select_value_field_value: "id",
        rails_fields_kit__tom_select_label_field_value: "title",
        rails_fields_kit__tom_select_option_description_field_value: "slug",
        rails_fields_kit__tom_select_placeholder_value: "文書名またはURL識別子で検索",
        rails_fields_kit__tom_select_min_length_value: 1,
        rails_fields_kit__tom_select_max_options_value: Admin::DocumentCatalogsController::DOCUMENT_SEARCH_LIMIT,
        action: "change->document-set-document-filter#pickRemoteDocument rails-fields-kit--tom-select:change->document-set-document-filter#pickRemoteDocument"
      }
    }
  end
end
