class CreateDocumentSets < ActiveRecord::Migration[8.1]
  def change
    create_table :document_sets do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :set_type, null: false, default: 0
      t.integer :visibility_policy, null: false, default: 0
      t.integer :sort_order, null: false, default: 0
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :document_sets, :public_id, unique: true
    add_index :document_sets, [:project_id, :name], unique: true
    add_index :document_sets, :set_type
    add_index :document_sets, :visibility_policy
    add_index :document_sets, :sort_order

    create_table :document_set_items do |t|
      t.references :document_set, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.references :document_version, foreign_key: true
      t.integer :sort_order, null: false, default: 0
      t.text :note

      t.timestamps
    end

    add_index :document_set_items, [:document_set_id, :document_id], unique: true
    add_index :document_set_items, :sort_order
  end
end
