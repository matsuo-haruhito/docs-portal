class CreateAccessLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :access_logs do |t|
      t.references :user, foreign_key: true
      t.references :company, foreign_key: true
      t.references :project, foreign_key: true
      t.references :document, foreign_key: true
      t.references :document_version, foreign_key: true
      t.integer :action_type, null: false
      t.string :target_type, null: false
      t.string :target_name
      t.string :ip_address
      t.text :user_agent
      t.datetime :accessed_at, null: false
      t.timestamps
    end
  end
end
