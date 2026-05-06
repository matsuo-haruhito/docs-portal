class CreateProjectConsentSettingsAndExpandUserConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :project_consent_settings do |t|
      t.string :public_id, null: false
      t.references :project, null: false, foreign_key: true
      t.references :consent_term, null: false, foreign_key: true
      t.integer :required_on, null: false, default: 0
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :project_consent_settings, :public_id, unique: true
    add_index :project_consent_settings, [:project_id, :consent_term_id, :required_on], unique: true, name: "index_project_consent_settings_unique_requirement"
    add_index :project_consent_settings, :required_on
    add_index :project_consent_settings, :enabled

    add_column :user_consents, :consent_term_version_label, :string
    add_index :user_consents, :consent_term_version_label

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE user_consents
          SET consent_term_version_label = consent_terms.version_label
          FROM consent_terms
          WHERE user_consents.consent_term_id = consent_terms.id
            AND user_consents.consent_term_version_label IS NULL
        SQL
      end
    end

    change_column_null :user_consents, :consent_term_version_label, false
    remove_index :user_consents, name: "index_user_consents_unique_user_term_target"
    add_index :user_consents,
      [:user_id, :consent_term_id, :target_type, :target_id, :consent_term_version_label],
      unique: true,
      name: "index_user_consents_unique_versioned_target"
  end
end
