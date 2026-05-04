class AddImportanceToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :importance_level, :integer, null: false, default: 2
    add_column :documents, :recommended_sort_order, :integer, null: false, default: 0
    add_column :documents, :reading_note, :text

    add_index :documents, :importance_level
    add_index :documents, :recommended_sort_order
  end
end
