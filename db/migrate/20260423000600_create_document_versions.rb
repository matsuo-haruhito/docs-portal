class CreateDocumentVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :document_versions do |t|
      t.references :document, null: false, foreign_key: true
      t.string :version_label, null: false
      t.integer :status, null: false, default: 0
      t.string :source_commit_hash, null: false
      t.text :changelog_summary
      t.datetime :published_at
      t.references :published_by_user, foreign_key: { to_table: :users }
      t.string :markdown_entry_path
      t.string :site_build_path
      t.string :pdf_snapshot_path
      t.text :notes
      t.timestamps
    end
    add_index :document_versions, [:document_id, :version_label], unique: true
  end
end
