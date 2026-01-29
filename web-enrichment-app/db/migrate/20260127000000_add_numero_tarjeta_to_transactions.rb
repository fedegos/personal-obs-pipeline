class AddNumeroTarjetaToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :numero_tarjeta, :string
  end
end
