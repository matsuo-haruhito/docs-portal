class CreateDocumentTags < ActiveRecord::Migration[8.1]
  def change
    create_table :document_tags do |t|
      t.string :public_id, null: false
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.timestamps
    end

    add_index :document_tags, :public_id, unique: true
    add_index :document_tags, :normalized_name, unique: true

    create_table :document_taggings do |t|
      t.references :document, null: false, foreign_key: true
      t.references :document_tag, null: false, foreign_key: true
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :document_taggings, [:document_id, :document_tag_id], unique: true
  end
end
