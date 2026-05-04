class CreateDocumentReviewComments < ActiveRecord::Migration[8.1]
  def change
    create_table :document_review_comments do |t|
      t.string :public_id, null: false
      t.references :document, null: false, foreign_key: true
      t.references :document_version, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.integer :comment_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :body, null: false
      t.boolean :internal_only, null: false, default: true
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :document_review_comments, :public_id, unique: true
    add_index :document_review_comments, :comment_type
    add_index :document_review_comments, :status
    add_index :document_review_comments, :internal_only
  end
end
