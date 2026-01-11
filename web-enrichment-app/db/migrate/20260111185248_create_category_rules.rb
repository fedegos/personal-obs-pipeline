class CreateCategoryRules < ActiveRecord::Migration[8.1]
  def change
    create_table :category_rules do |t|
      t.string :name
      t.string :pattern
      t.integer :priority
      t.integer :parent_id

      t.timestamps
    end
    add_index :category_rules, :parent_id
  end
end
