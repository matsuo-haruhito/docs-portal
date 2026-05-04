class AddSourceMetadataIndexesToDocumentVersions < ActiveRecord::Migration[8.1]
  def change
    add_index :document_versions,
              :source_basename,
              name: "index_document_versions_on_source_basename"
  end
end
