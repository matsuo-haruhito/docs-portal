class CreateConsentTermsAndUserConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :consent_terms do |t|
      t.string :public_id, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :version_label, null: false
      t.boolean :active, null: false, default: true
      t.integer :consent_scope, null: false, default: 0
      t.integer :requirement_timing, null: false, default: 0

      t.timestamps
    end

    add_index :consent_terms, :public_id, unique: true
    add_index :consent_terms, [:title, :version_label], unique: true
    add_index :consent_terms, :active
    add_index :consent_terms, :consent_scope
    add_index :consent_terms, :requirement_timing

    create_table :user_consents do |t|
      t.string :public_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :consent_term, null: false, foreign_key: true
      t.string :target_type
      t.bigint :target_id
      t.datetime :consented_at, null: false
      t.string :ip_address
      t.text :user_agent

      t.timestamps
    end

    add_index :user_consents, :public_id, unique: true
    add_index :user_consents, [:user_id, :consent_term_id, :target_type, :target_id], unique: true, name: "index_user_consents_unique_user_term_target"
    add_index :user_consents, [:target_type, :target_id]
    add_index :user_consents, :consented_at
  end
end
