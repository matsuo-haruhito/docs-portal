class AddRoleFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.integer :user_type, null: false, default: 0
      t.references :company, foreign_key: true
      t.boolean :active, null: false, default: true
      t.datetime :last_login_at
      t.string :name, null: false, default: ""
    end
    add_index :users, :user_type
  end
end
