# frozen_string_literal: true

class AddManuallyEditedToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :manually_edited, :boolean, default: false, null: false
  end
end
