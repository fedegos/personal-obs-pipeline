class CreateSolidCableMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false, limit: 1024
      t.binary :payload, null: false, limit: 536870912
      t.datetime :created_at, precision: 6, null: false
      
      # Esta es la columna que falta
      t.integer :channel_hash, limit: 8, null: false 

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end