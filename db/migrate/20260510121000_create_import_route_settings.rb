class CreateImportRouteSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :import_route_settings do |t|
      t.references :project, null: true, foreign_key: true
      t.string :route_key, null: false
      t.string :setting_key, null: false
      t.string :setting_value, null: false
      t.timestamps
    end

    add_index :import_route_settings,
      [:project_id, :route_key, :setting_key],
      unique: true,
      name: "index_import_route_settings_on_project_route_and_key"
  end
end
