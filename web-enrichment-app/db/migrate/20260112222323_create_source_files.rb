class CreateSourceFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :source_files do |t|
      t.string :bank
      t.string :file_key
      t.string :status
      t.text :error_message
      t.jsonb :extra_params
      t.datetime :processed_at

      t.timestamps
    end
    add_index :source_files, :file_key
  end
end
