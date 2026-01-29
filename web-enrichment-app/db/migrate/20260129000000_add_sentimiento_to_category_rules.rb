# frozen_string_literal: true

class AddSentimientoToCategoryRules < ActiveRecord::Migration[8.1]
  def change
    add_column :category_rules, :sentimiento, :string
  end
end
