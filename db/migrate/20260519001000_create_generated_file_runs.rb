class CreateGeneratedFileRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :generated_file_runs do |t|
      t.string :public_id, null: false
      t.string :job_id, null: false
      t.string :generator
      t.string :output_writer
      t.integer :status, null: false, default: 0
      t.string :event_source
      t.json :source_paths, null: false, default: []
      t.json :changed_files, null: false, default: []
      t.json :generated_paths, null: false, default: []
      t.json :metadata, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end

    add_index :generated_file_runs, :public_id, unique: true
    add_index :generated_file_runs, :job_id
    add_index :generated_file_runs, :status
    add_index :generated_file_runs, :event_source
    add_index :generated_file_runs, :started_at
    add_index :generated_file_runs, [:job_id, :started_at]
  end
end
