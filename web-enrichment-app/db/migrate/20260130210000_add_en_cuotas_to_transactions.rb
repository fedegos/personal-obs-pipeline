# frozen_string_literal: true

class AddEnCuotasToTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :transactions, :en_cuotas, :boolean, default: false, null: false
    add_column :transactions, :descripcion_cuota, :string
  end
end
