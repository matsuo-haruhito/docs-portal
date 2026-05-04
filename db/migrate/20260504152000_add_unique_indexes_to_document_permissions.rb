class AddUniqueIndexesToDocumentPermissions < ActiveRecord::Migration[8.1]
  def change
    add_index :document_permissions,
      [:document_id, :company_id],
      unique: true,
      where: "company_id IS NOT NULL AND user_id IS NULL",
      name: "index_document_permissions_unique_company_scope"

    add_index :document_permissions,
      [:document_id, :user_id],
      unique: true,
      where: "user_id IS NOT NULL AND company_id IS NULL",
      name: "index_document_permissions_unique_user_scope"
  end
end
