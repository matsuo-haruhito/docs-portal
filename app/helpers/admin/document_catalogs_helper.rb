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
end
