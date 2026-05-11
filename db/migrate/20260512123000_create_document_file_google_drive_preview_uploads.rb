class CreateDocumentFileGoogleDrivePreviewUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :document_file_google_drive_preview_uploads do |t|
      t.string :public_id, null: false
      t.references :document_file, null: false, foreign_key: true, index: { name: "idx_google_preview_uploads_on_document_file" }
      t.string :fingerprint, null: false
      t.string :drive_file_id, null: false
      t.string :drive_web_view_link
      t.datetime :uploaded_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :deleted_at
      t.text :last_error_message
      t.timestamps
    end

    add_index :document_file_google_drive_preview_uploads, :public_id, unique: true
    add_index :document_file_google_drive_preview_uploads, [:document_file_id, :fingerprint, :deleted_at], name: "idx_google_preview_uploads_on_file_fingerprint_deleted"
    add_index :document_file_google_drive_preview_uploads, [:expires_at, :deleted_at], name: "idx_google_preview_uploads_on_expires_deleted"
  end
end
