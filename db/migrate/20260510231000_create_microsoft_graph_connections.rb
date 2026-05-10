class CreateMicrosoftGraphConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :microsoft_graph_connections do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :auth_type, null: false, default: 0
      t.string :tenant_id, null: false
      t.string :client_id, null: false
      t.text :client_secret, null: false
      t.string :site_id
      t.string :drive_id, null: false
      t.string :preview_folder_path, null: false, default: "docs-portal-previews"
      t.boolean :enabled, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :microsoft_graph_connections, :public_id, unique: true
    add_index :microsoft_graph_connections, [:project_id, :name], unique: true
    add_index :microsoft_graph_connections, [:project_id, :enabled]
    add_index :microsoft_graph_connections, :tenant_id
    add_index :microsoft_graph_connections, :drive_id
  end
end
