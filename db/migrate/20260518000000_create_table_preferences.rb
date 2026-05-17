# frozen_string_literal: true

class CreateTablePreferences < ActiveRecord::Migration[7.0]
  def change
    create_table :table_preferences do |t|
      t.references :user, null: true, foreign_key: true
      t.string :scope_type, null: false, default: "owner"
      t.string :scope_key
      t.string :table_key, null: false
      t.string :name, null: false, default: "default"
      t.json :settings, null: false
      t.boolean :default_flag, null: false, default: false
      t.timestamps
    end

    add_index :table_preferences,
              [:scope_type, :scope_key, :user_id, :table_key, :name],
              unique: true,
              name: "idx_table_preferences_scope_table_name"
    add_index :table_preferences,
              [:scope_type, :scope_key, :user_id, :table_key, :default_flag],
              name: "idx_table_preferences_scope_table_default"
  end
end