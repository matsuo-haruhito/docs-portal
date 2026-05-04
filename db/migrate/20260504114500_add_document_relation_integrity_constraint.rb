class AddDocumentRelationIntegrityConstraint < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :document_relations,
                         "source_document_id <> target_document_id",
                         name: "document_relations_source_target_different"
  end
end
