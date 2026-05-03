class CreateDocumentKeywords < ActiveRecord::Migration[8.1]
  def change
    create_table :document_keywords do |t|
      t.references :document, null: false, foreign_key: true
      t.string :public_id, null: false
      t.string :keyword, null: false
      t.string :normalized_keyword, null: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :document_keywords, :public_id, unique: true
    add_index :document_keywords, [:document_id, :normalized_keyword], unique: true
    add_index :document_keywords, :normalized_keyword
  end
end
