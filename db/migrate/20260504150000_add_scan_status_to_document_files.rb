class AddScanStatusToDocumentFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :document_files, :scan_status, :integer, null: false, default: 0
    add_column :document_files, :scanned_at, :datetime
    add_column :document_files, :scan_error_message, :text

    add_index :document_files, :scan_status
  end
end
