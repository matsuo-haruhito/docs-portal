class CreateImportDryRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :import_dry_runs do |t|
      t.string :public_id, null: false
      t.integer :import_mode, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.bigint :project_id
      t.bigint :created_by_id, null: false
      t.bigint :confirmed_by_id
      t.string :source_commit_hash
      t.json :summary_json, null: false, default: {}
      t.json :result_json, null: false, default: {}
      t.json :warnings_json, null: false, default: []
      t.json :errors_json, null: false, default: []
      t.datetime :confirmed_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :import_dry_runs, :public_id, unique: true
    add_index :import_dry_runs, :import_mode
    add_index :import_dry_runs, :status
    add_index :import_dry_runs, :project_id
    add_index :import_dry_runs, :created_by_id
    add_index :import_dry_runs, :confirmed_by_id

    add_foreign_key :import_dry_runs, :projects
    add_foreign_key :import_dry_runs, :users, column: :created_by_id
    add_foreign_key :import_dry_runs, :users, column: :confirmed_by_id
  end
end
