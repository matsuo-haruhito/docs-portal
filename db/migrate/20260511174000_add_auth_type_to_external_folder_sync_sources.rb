class AddAuthTypeToExternalFolderSyncSources < ActiveRecord::Migration[8.1]
  def change
    add_column :external_folder_sync_sources, :auth_type, :integer, null: false, default: 0
    add_index :external_folder_sync_sources, [:provider, :auth_type], name: "idx_ext_sync_sources_on_provider_auth_type"
  end
end
