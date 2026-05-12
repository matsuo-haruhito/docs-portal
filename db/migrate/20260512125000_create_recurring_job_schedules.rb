class CreateRecurringJobSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_job_schedules do |t|
      t.string :public_id, null: false
      t.string :job_key, null: false
      t.string :job_class, null: false
      t.string :queue_name, null: false, default: "default"
      t.boolean :enabled, null: false, default: true
      t.boolean :allow_overlap, null: false, default: false
      t.integer :interval_seconds, null: false, default: 86_400
      t.json :args_json, null: false, default: {}
      t.text :description
      t.datetime :next_run_at, null: false
      t.datetime :last_enqueued_at
      t.datetime :last_started_at
      t.datetime :last_finished_at
      t.datetime :run_requested_at
      t.string :last_status
      t.text :last_error_message
      t.datetime :locked_at
      t.string :locked_by
      t.timestamps
    end

    add_index :recurring_job_schedules, :public_id, unique: true
    add_index :recurring_job_schedules, :job_key, unique: true
    add_index :recurring_job_schedules, [:enabled, :next_run_at], name: "idx_recurring_job_schedules_on_enabled_next_run_at"
    add_index :recurring_job_schedules, :run_requested_at

    create_table :recurring_job_runs do |t|
      t.string :public_id, null: false
      t.references :recurring_job_schedule, null: false, foreign_key: true, index: { name: "idx_recurring_job_runs_on_schedule" }
      t.string :job_key, null: false
      t.string :job_class, null: false
      t.string :queue_name, null: false, default: "default"
      t.json :args_json, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.string :active_job_id
      t.datetime :scheduled_at, null: false
      t.datetime :enqueued_at
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.json :metadata_json, null: false, default: {}
      t.timestamps
    end

    add_index :recurring_job_runs, :public_id, unique: true
    add_index :recurring_job_runs, [:job_key, :scheduled_at], name: "idx_recurring_job_runs_on_job_key_scheduled_at"
    add_index :recurring_job_runs, [:status, :scheduled_at], name: "idx_recurring_job_runs_on_status_scheduled_at"
  end
end
