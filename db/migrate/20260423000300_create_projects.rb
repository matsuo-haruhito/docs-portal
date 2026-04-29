class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :projects, :code, unique: true
  end
end
