class CreateGeneratedFileEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :generated_file_events do |t|
      t.string :public_id, null: false
      t.string :event_key, null: false
      t.string :path, null: false
      t.string :operation, null: false
      t.string :event_source
      t.integer :status, null: false, default: 0
      t.json :metadata, null: false, default: {}
      t.datetime :scheduled_at, null: false
      t.datetime :last_seen_at, null: false
      t.datetime :processed_at
      t.integer :occurrences_count, null: false, default: 1
      t.text :error_message

      t.timestamps
    end

    add_index :generated_file_events, :public_id, unique: true
    add_index :generated_file_events, :event_key
    add_index :generated_file_events, :path
    add_index :generated_file_events, :operation
    add_index :generated_file_events, :event_source
    add_index :generated_file_events, :status
    add_index :generated_file_events, :scheduled_at
    add_index :generated_file_events, [:status, :scheduled_at]
    add_index :generated_file_events, [:event_key, :status]
  end
end
