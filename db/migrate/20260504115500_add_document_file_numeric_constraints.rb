class AddDocumentFileNumericConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :document_files,
                         "file_size >= 0",
                         name: "document_files_file_size_non_negative"

    add_check_constraint :document_files,
                         "sort_order >= 0",
                         name: "document_files_sort_order_non_negative"
  end
end
