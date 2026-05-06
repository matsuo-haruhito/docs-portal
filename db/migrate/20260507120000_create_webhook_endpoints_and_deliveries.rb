class CreateWebhookEndpointsAndDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints do |t|
      t.string :public_id, null: false
      t.string :name, null: false
      t.string :target_url, null: false
      t.string :secret_token
      t.boolean :active, null: false, default: true
      t.json :event_types, null: false, default: []
      t.json :headers_json, null: false, default: {}
      t.timestamps

      t.index :public_id, unique: true
      t.index :active
      t.index :name
    end

    create_table :webhook_deliveries do |t|
      t.string :public_id, null: false
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.references :notification_event, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :event_type, null: false
      t.string :target_url, null: false
      t.text :request_body, null: false
      t.integer :response_status
      t.text :response_body
      t.text :error_message
      t.datetime :sent_at
      t.timestamps

      t.index :public_id, unique: true
      t.index :status
      t.index :event_type
      t.index :sent_at
    end
  end
end
