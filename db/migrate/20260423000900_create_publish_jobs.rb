class CreatePublishJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :publish_jobs do |t|
      t.string :source_repo, null: false
      t.string :source_branch, null: false
      t.string :source_commit_hash, null: false
      t.string :artifact_path
      t.integer :status, null: false, default: 0
      t.text :log_message
      t.timestamps
    end
  end
end
