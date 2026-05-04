class CreateDocumentCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :document_catalogs do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :audience_type, null: false, default: 0
      t.integer :visibility_policy, null: false, default: 0
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    add_index :document_catalogs, :public_id, unique: true
    add_index :document_catalogs, [:project_id, :name], unique: true
    add_index :document_catalogs, :audience_type
    add_index :document_catalogs, :visibility_policy
    add_index :document_catalogs, :sort_order

    create_table :document_catalog_items do |t|
      t.references :document_catalog, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :sort_order, null: false, default: 0
      t.text :note

      t.timestamps
    end

    add_index :document_catalog_items, [:document_catalog_id, :document_id], unique: true, name: "index_document_catalog_items_unique_catalog_document"
    add_index :document_catalog_items, :sort_order
  end
end
