class AddPublicationWindowToDocumentVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :document_versions, :published_from, :datetime
    add_column :document_versions, :published_until, :datetime

    add_index :document_versions, :published_from
    add_index :document_versions, :published_until
  end
end
