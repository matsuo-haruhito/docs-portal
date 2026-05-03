class CreateDocumentRelations < ActiveRecord::Migration[8.0]
  def change
    create_table :document_relations do |t|
      t.references :source_document, null: false, foreign_key: { to_table: :documents }
      t.references :target_document, null: false, foreign_key: { to_table: :documents }
      t.integer :relation_type, null: false, default: 0
      t.integer :sort_order, null: false, default: 0
      t.text :note
      t.string :public_id, null: false
      t.timestamps
    end

    add_index :document_relations, :public_id, unique: true
    add_index :document_relations,
      [:source_document_id, :target_document_id, :relation_type],
      unique: true,
      name: "index_document_relations_unique_relation"
  end
end
