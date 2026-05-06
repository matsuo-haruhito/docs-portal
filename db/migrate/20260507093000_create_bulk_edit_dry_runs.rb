class CreateBulkEditDryRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :bulk_edit_dry_runs do |t|
      t.string :public_id, null: false
      t.references :project, null: true, foreign_key: true
      t.integer :operation_type, null: false, default: 0
      t.json :target_document_ids, null: false, default: []
      t.json :params_json, null: false, default: {}
      t.json :summary_json, null: false, default: {}
      t.json :result_json, null: false, default: {}
      t.json :warnings_json, null: false, default: []
      t.json :errors_json, null: false, default: []
      t.integer :status, null: false, default: 0
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :confirmed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :bulk_edit_dry_runs, :public_id, unique: true
    add_index :bulk_edit_dry_runs, :operation_type
    add_index :bulk_edit_dry_runs, :status
  end
end
