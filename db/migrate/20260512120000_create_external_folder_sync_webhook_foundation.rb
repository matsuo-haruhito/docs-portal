class CreateExternalFolderSyncWebhookFoundation < ActiveRecord::Migration[8.1]
  def change
    create_table :external_folder_sync_subscriptions do |t|
      t.string :public_id, null: false
      t.references :external_folder_sync_source, null: false, foreign_key: true, index: { name: "idx_ext_sync_subscriptions_on_source" }
      t.integer :provider, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :provider_subscription_id
      t.string :provider_channel_id
      t.string :provider_resource_id
      t.string :callback_url
      t.string :verification_token_digest
      t.datetime :expires_at
      t.datetime :last_renewed_at
      t.text :last_error_message
      t.json :provider_metadata, null: false, default: {}
      t.timestamps
    end

    add_index :external_folder_sync_subscriptions, :public_id, unique: true
    add_index :external_folder_sync_subscriptions, [:provider, :provider_subscription_id], name: "idx_ext_sync_subscriptions_on_provider_subscription"
    add_index :external_folder_sync_subscriptions, [:provider, :provider_channel_id], name: "idx_ext_sync_subscriptions_on_provider_channel"
    add_index :external_folder_sync_subscriptions, [:status, :expires_at], name: "idx_ext_sync_subscriptions_on_status_expires_at"

    create_table :external_folder_sync_webhook_events do |t|
      t.string :public_id, null: false
      t.references :external_folder_sync_source, foreign_key: true, index: { name: "idx_ext_sync_webhook_events_on_source" }
      t.references :external_folder_sync_subscription, foreign_key: true, index: { name: "idx_ext_sync_webhook_events_on_subscription" }
      t.integer :provider, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :event_key
      t.datetime :received_at, null: false
      t.json :headers_json, null: false, default: {}
      t.json :payload_json, null: false, default: {}
      t.text :error_message
      t.timestamps
    end

    add_index :external_folder_sync_webhook_events, :public_id, unique: true
    add_index :external_folder_sync_webhook_events, [:provider, :event_key], unique: true, name: "idx_ext_sync_webhook_events_unique_provider_event"
    add_index :external_folder_sync_webhook_events, [:status, :received_at], name: "idx_ext_sync_webhook_events_on_status_received_at"
  end
end
