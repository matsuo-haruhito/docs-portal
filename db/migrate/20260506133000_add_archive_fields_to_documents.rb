class AddArchiveFieldsToDocuments < ActiveRecord::Migration[8.1]
  def change
    change_table :documents, bulk: true do |t|
      t.datetime :archived_at
      t.references :archived_by_user, foreign_key: { to_table: :users }
      t.datetime :retention_until
      t.datetime :discard_candidate_at
    end

    add_index :documents, :archived_at
    add_index :documents, :retention_until
    add_index :documents, :discard_candidate_at
  end
end
