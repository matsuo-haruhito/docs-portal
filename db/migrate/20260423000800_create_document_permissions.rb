class CreateDocumentPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :document_permissions do |t|
      t.references :document, null: false, foreign_key: true
      t.references :company, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :access_level, null: false, default: 0
      t.timestamps
    end
  end
end
