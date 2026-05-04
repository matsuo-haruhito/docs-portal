class CreateReadConfirmations < ActiveRecord::Migration[8.1]
  def change
    create_table :read_confirmations do |t|
      t.string :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.references :document_version, foreign_key: true
      t.datetime :confirmed_at, null: false

      t.timestamps
    end

    add_index :read_confirmations, :public_id, unique: true
    add_index :read_confirmations, [:user_id, :document_id], unique: true, name: "index_read_confirmations_unique_user_document"
    add_index :read_confirmations, :confirmed_at
  end
end
