class CreateDocumentDeliveryLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :document_delivery_logs do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.references :document, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :to_addresses, null: false
      t.text :cc_addresses
      t.text :bcc_addresses
      t.string :subject, null: false
      t.text :body, null: false
      t.integer :delivery_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :sent_at
      t.text :error_message

      t.timestamps
    end

    add_index :document_delivery_logs, :public_id, unique: true
    add_index :document_delivery_logs, :delivery_type
    add_index :document_delivery_logs, :status
    add_index :document_delivery_logs, :sent_at
  end
end
