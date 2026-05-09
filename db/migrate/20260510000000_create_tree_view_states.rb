class CreateTreeViewStates < ActiveRecord::Migration[8.1]
  def change
    create_table :tree_view_states do |t|
      t.references :owner, polymorphic: true, null: false
      t.string :tree_instance_key, null: false
      t.json :expanded_keys, null: false, default: []

      t.timestamps
    end

    add_index :tree_view_states, [:owner_type, :owner_id, :tree_instance_key], unique: true
  end
end
