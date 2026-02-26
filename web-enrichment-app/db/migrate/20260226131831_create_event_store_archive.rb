# frozen_string_literal: true

class CreateEventStoreArchive < ActiveRecord::Migration[8.0]
  def change
    create_table :event_store_archive, id: false do |t|
      t.bigserial :sequence_number, primary_key: true
      t.uuid :id, null: false
      t.string :event_type, null: false, limit: 255
      t.integer :event_version, null: false, default: 1
      t.timestamptz :occurred_at, null: false
      t.string :aggregate_type, null: false, limit: 255
      t.string :aggregate_id, null: false, limit: 255
      t.string :stream_id, null: false, limit: 512
      t.uuid :causation_id
      t.uuid :correlation_id
      t.jsonb :metadata
      t.jsonb :body, null: false
      t.timestamptz :created_at, null: false, default: -> { "now()" }
      t.timestamptz :archived_at, null: false, default: -> { "now()" }
    end

    add_index :event_store_archive, :id, unique: true
    add_index :event_store_archive, :occurred_at
    add_index :event_store_archive, :archived_at
  end
end
