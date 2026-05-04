class CreateDocumentBookmarks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_bookmarks do |t|
      t.string :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :bookmark_type, null: false, default: 0

      t.timestamps
    end

    add_index :document_bookmarks, :public_id, unique: true
    add_index :document_bookmarks, [:user_id, :document_id, :bookmark_type], unique: true, name: "index_document_bookmarks_unique_user_document_type"
  end
end
