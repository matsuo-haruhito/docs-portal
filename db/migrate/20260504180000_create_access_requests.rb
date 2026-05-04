class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests do |t|
      t.string :public_id, null: false
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :approver, foreign_key: { to_table: :users }
      t.references :project, foreign_key: true
      t.references :document, foreign_key: true
      t.integer :requested_access_level, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :reason, null: false
      t.text :rejection_reason
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :access_requests, :public_id, unique: true
    add_index :access_requests, :requested_access_level
    add_index :access_requests, :status
    add_index :access_requests, :expires_at
  end
end
