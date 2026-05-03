class AddSourcePathMetadataToDocumentVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :document_versions, :source_relative_path, :string
    add_column :document_versions, :source_directory, :string
    add_column :document_versions, :source_file_name, :string
    add_column :document_versions, :source_basename, :string
    add_column :document_versions, :source_extension, :string
    add_column :document_versions, :snapshot_kind, :string

    add_index :document_versions, :source_relative_path
    add_index :document_versions, :source_directory
    add_index :document_versions, :snapshot_kind
  end
end
