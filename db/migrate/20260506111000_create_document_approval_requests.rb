class CreateDocumentApprovalRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :document_approval_requests do |t|
      t.string :public_id, null: false
      t.references :document, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :approver, foreign_key: { to_table: :users }
      t.references :acted_by, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body
      t.integer :status, null: false, default: 0
      t.datetime :approved_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :document_approval_requests, :public_id, unique: true
    add_index :document_approval_requests, :status
    add_index :document_approval_requests, :approved_at
    add_index :document_approval_requests, :cancelled_at
  end
end
