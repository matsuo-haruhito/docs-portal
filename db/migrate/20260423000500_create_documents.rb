class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :category, null: false, default: 0
      t.integer :document_kind, null: false, default: 0
      t.integer :visibility_policy, null: false, default: 0
      t.bigint :latest_version_id
      t.timestamps
    end
    add_index :documents, [:project_id, :slug], unique: true
    add_index :documents, :latest_version_id
  end
end
