class AddFilterIndexesToDocumentVersions < ActiveRecord::Migration[8.1]
  def change
    add_index :document_versions,
              :site_build_path,
              name: "index_document_versions_on_site_build_path"

    add_index :document_versions,
              :source_extension,
              name: "index_document_versions_on_source_extension"
  end
end
