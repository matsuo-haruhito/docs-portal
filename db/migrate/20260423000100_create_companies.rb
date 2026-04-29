class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :companies, :code, unique: true
  end
end
