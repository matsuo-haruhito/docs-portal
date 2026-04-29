class CreateDocumentFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :document_files do |t|
      t.references :document_version, null: false, foreign_key: true
      t.string :file_name, null: false
      t.string :content_type, null: false
      t.string :storage_key, null: false
      t.bigint :file_size, null: false, default: 0
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
    add_index :document_files, :storage_key, unique: true
  end
end
