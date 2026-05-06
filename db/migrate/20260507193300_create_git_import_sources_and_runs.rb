class CreateGitImportSourcesAndRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :git_import_sources do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.integer :provider, null: false, default: 0
      t.string :organization_name
      t.string :repository_full_name, null: false
      t.string :branch, null: false, default: "main"
      t.string :source_path, null: false, default: "docs"
      t.integer :auth_type, null: false, default: 0
      t.string :installation_id
      t.string :credential_ref
      t.text :credential_secret_ciphertext
      t.string :last_synced_commit_sha
      t.datetime :last_synced_at
      t.boolean :enabled, null: false, default: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :git_import_sources, :public_id, unique: true
    add_index :git_import_sources, [:project_id, :repository_full_name, :branch, :source_path], unique: true, name: "index_git_import_sources_unique_target"
    add_index :git_import_sources, :repository_full_name
    add_index :git_import_sources, :enabled

    create_table :git_import_runs do |t|
      t.string :public_id, null: false
      t.references :git_import_source, foreign_key: true
      t.integer :import_mode, null: false, default: 0
      t.integer :provider, null: false, default: 0
      t.string :repository_full_name, null: false
      t.string :branch, null: false
      t.string :source_path, null: false
      t.string :commit_sha
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.json :summary_json, null: false, default: {}
      t.text :error_message

      t.timestamps
    end

    add_index :git_import_runs, :public_id, unique: true
    add_index :git_import_runs, :status
    add_index :git_import_runs, :commit_sha
  end
end
