class ExpandDocumentReviewComments < ActiveRecord::Migration[8.1]
  def change
    change_table :document_review_comments, bulk: true do |t|
      t.references :parent, foreign_key: { to_table: :document_review_comments }
      t.integer :text_line_start
      t.integer :text_line_end
      t.string :text_anchor_type
      t.string :text_anchor_path
      t.string :text_anchor_label
      t.string :source_path
    end
  end
end
