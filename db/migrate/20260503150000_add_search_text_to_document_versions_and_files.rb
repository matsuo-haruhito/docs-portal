class AddSearchTextToDocumentVersionsAndFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :document_versions, :search_body_text, :text
    add_column :document_files, :search_text, :text
  end
end
