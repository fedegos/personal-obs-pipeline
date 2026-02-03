# frozen_string_literal: true

class AddProcessingResultToSourceFiles < ActiveRecord::Migration[8.1]
  def change
    add_column :source_files, :transactions_count, :integer
    add_column :source_files, :processing_message, :string
  end
end
