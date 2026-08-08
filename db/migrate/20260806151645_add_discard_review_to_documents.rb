class AddDiscardReviewToDocuments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :documents, :discard_reviewed_at, :datetime, comment: "廃棄候補確認日時"
    add_column :documents, :discard_reviewed_by_id, :bigint, comment: "廃棄候補確認者ID"
    add_index :documents, :discard_reviewed_at, algorithm: :concurrently
  end
end
