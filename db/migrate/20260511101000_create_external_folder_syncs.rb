class CreateExternalFolderSyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :external_folder_sync_sources do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.integer :provider, null: false, default: 0
      t.string :name, null: false
      t.string :folder_url, null: false
      t.string :external_folder_id, null: false
      t.string :external_folder_path
      t.integer :sync_direction, null: false, default: 0
      t.integer :conflict_policy, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.text :auth_config, null: false
      t.text :cursor
      t.datetime :last_synced_at
      t.text :last_error_message
      t.json :provider_metadata, null: false, default: {}
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :external_folder_sync_sources, :public_id, unique: true
    add_index :external_folder_sync_sources, [:project_id, :provider, :name], unique: true, name: "idx_ext_sync_sources_unique_project_provider_name"
    add_index :external_folder_sync_sources, [:provider, :external_folder_id], name: "idx_ext_sync_sources_on_provider_folder"
    add_index :external_folder_sync_sources, [:project_id, :enabled], name: "idx_ext_sync_sources_on_project_enabled"

    create_table :external_folder_sync_runs do |t|
      t.string :public_id, null: false
      t.references :external_folder_sync_source, null: false, foreign_key: true, index: { name: "idx_ext_sync_runs_on_source" }
      t.integer :status, null: false, default: 0
      t.integer :mode, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :items_scanned_count, null: false, default: 0
      t.integer :items_created_count, null: false, default: 0
      t.integer :items_updated_count, null: false, default: 0
      t.integer :items_skipped_count, null: false, default: 0
      t.integer :items_deleted_count, null: false, default: 0
      t.integer :errors_count, null: false, default: 0
      t.text :error_message
      t.json :summary_json, null: false, default: {}
      t.json :result_json, null: false, default: []
      t.timestamps
    end

    add_index :external_folder_sync_runs, :public_id, unique: true
    add_index :external_folder_sync_runs, [:status, :started_at], name: "idx_ext_sync_runs_on_status_started_at"
    add_index :external_folder_sync_runs, [:mode, :started_at], name: "idx_ext_sync_runs_on_mode_started_at"

    create_table :external_folder_sync_items do |t|
      t.string :public_id, null: false
      t.references :external_folder_sync_source, null: false, foreign_key: true, index: { name: "idx_ext_sync_items_on_source" }
      t.references :document, foreign_key: true
      t.references :document_version, foreign_key: true
      t.references :document_file, foreign_key: true
      t.string :external_item_id, null: false
      t.string :external_parent_id
      t.string :path, null: false
      t.string :name, null: false
      t.string :mime_type
      t.bigint :size
      t.string :checksum
      t.datetime :external_modified_at
      t.datetime :portal_modified_at
      t.integer :sync_status, null: false, default: 0
      t.text :last_error_message
      t.json :provider_metadata, null: false, default: {}
      t.timestamps
    end

    add_index :external_folder_sync_items, :public_id, unique: true
    add_index :external_folder_sync_items, [:external_folder_sync_source_id, :external_item_id], unique: true, name: "idx_ext_sync_items_unique_source_item"
    add_index :external_folder_sync_items, [:sync_status, :updated_at], name: "idx_ext_sync_items_on_status_updated_at"
    add_index :external_folder_sync_items, :path, name: "idx_ext_sync_items_on_path"
  end
end
