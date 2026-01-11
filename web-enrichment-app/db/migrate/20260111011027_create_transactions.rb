class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      # El event_id es nuestra clave única para evitar duplicados de Kafka
      t.string :event_id, null: false
      t.datetime :fecha, null: false
      
      # Usamos decimal 15,2 para evitar errores de redondeo de punto flotante
      t.decimal :monto, precision: 15, scale: 2, null: false
      
      t.string :moneda
      t.string :detalles
      t.string :categoria
      t.string :sub_categoria
      t.string :sentimiento
      t.string :red
      
      # Control de flujo para el tópico 'transaction_clean'
      t.boolean :aprobado, default: false, null: false

      t.timestamps
    end
    
    # Índice único para asegurar que no procesemos dos veces el mismo gasto
    add_index :transactions, :event_id, unique: true
    # Índice para búsquedas rápidas en la web
    add_index :transactions, :aprobado  end
end
