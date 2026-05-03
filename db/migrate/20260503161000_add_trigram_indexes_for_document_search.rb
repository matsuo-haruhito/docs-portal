class AddTrigramIndexesForDocumentSearch < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :documents,
      :title,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_documents_on_title_trigram"
    add_index :documents,
      :slug,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_documents_on_slug_trigram"

    add_index :document_versions,
      :version_label,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_versions_on_version_label_trigram"
    add_index :document_versions,
      :source_relative_path,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_versions_on_source_relative_path_trigram"
    add_index :document_versions,
      :source_directory,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_versions_on_source_directory_trigram"
    add_index :document_versions,
      :source_file_name,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_versions_on_source_file_name_trigram"
    add_index :document_versions,
      :search_body_text,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_versions_on_search_body_text_trigram"

    add_index :document_files,
      :file_name,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_files_on_file_name_trigram"
    add_index :document_files,
      :search_text,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_files_on_search_text_trigram"

    add_index :document_keywords,
      :keyword,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_keywords_on_keyword_trigram"
    add_index :document_keywords,
      :normalized_keyword,
      using: :gin,
      opclass: :gin_trgm_ops,
      name: "index_document_keywords_on_normalized_keyword_trigram"
  end
end
