class AddSortOrderConstraintsToDocumentMetadata < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :document_keywords,
                         "sort_order >= 0",
                         name: "document_keywords_sort_order_non_negative"

    add_check_constraint :document_relations,
                         "sort_order >= 0",
                         name: "document_relations_sort_order_non_negative"

    add_check_constraint :document_taggings,
                         "sort_order >= 0",
                         name: "document_taggings_sort_order_non_negative"
  end
end
