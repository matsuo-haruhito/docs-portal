class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :access_requests do |t|
      t.string :public_id, null: false
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :approver, foreign_key: { to_table: :users }
      t.string :requestable_type, null: false
      t.bigint :requestable_id, null: false
      t.integer :requested_access_level, null: false, default: 0
      t.text :reason
      t.integer :status, null: false, default: 0
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :cancelled_at
      t.text :rejection_reason
      t.datetime :expires_at

      t.timestamps
    end

    add_index :access_requests, :public_id, unique: true
    add_index :access_requests, [:requestable_type, :requestable_id]
    add_index :access_requests, :requested_access_level
    add_index :access_requests, :status
    add_index :access_requests, :approved_at
    add_index :access_requests, :rejected_at
    add_index :access_requests, :expires_at
    add_index :access_requests,
      [:requester_id, :requestable_type, :requestable_id, :requested_access_level, :status],
      name: "index_access_requests_unique_pending",
      unique: true,
      where: "status = 0"
  end
end
