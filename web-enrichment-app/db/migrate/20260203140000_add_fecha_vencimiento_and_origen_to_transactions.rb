# frozen_string_literal: true

class AddFechaVencimientoAndOrigenToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :fecha_vencimiento, :date
    add_column :transactions, :origen, :string, default: "definitivo", null: false
  end
end
