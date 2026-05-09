class CreateNotificationEventsAndReceipts < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:notification_events) && table_exists?(:notification_receipts)

    create_table :notification_events, if_not_exists: true do |t|
      t.string :public_id, null: false
      t.integer :event_type, null: false
      t.references :project, foreign_key: true
      t.references :document, foreign_key: true
      t.references :document_version, foreign_key: true
      t.references :actor_user, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :notification_events, :public_id, unique: true, if_not_exists: true
    add_index :notification_events, :event_type, if_not_exists: true
    add_index :notification_events, :occurred_at, if_not_exists: true

    create_table :notification_receipts, if_not_exists: true do |t|
      t.string :public_id, null: false
      t.references :notification_event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :read_at

      t.timestamps
    end

    add_index :notification_receipts, :public_id, unique: true, if_not_exists: true
    add_index :notification_receipts, [:notification_event_id, :user_id], unique: true, name: "index_notification_receipts_unique_event_user", if_not_exists: true
    add_index :notification_receipts, :read_at, if_not_exists: true
  end
end
