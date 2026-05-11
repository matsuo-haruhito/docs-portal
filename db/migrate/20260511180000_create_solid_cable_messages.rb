class CreateSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false, limit: 1024
      t.binary :payload, null: false, limit: 536870912
      t.datetime :created_at, null: false
    end

    add_index :solid_cable_messages, :created_at
    add_index :solid_cable_messages, :channel
    add_index :solid_cable_messages, :channel, length: 1024, name: :index_solid_cable_messages_on_channel_hash
  end
end
