# frozen_string_literal: true

class CreateEventStore < ActiveRecord::Migration[8.0]
  def change
    create_table :event_store, id: false do |t|
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
    end

    add_index :event_store, :id, unique: true
    add_index :event_store, :occurred_at
    add_index :event_store, [ :stream_id, :occurred_at ]
    add_index :event_store, [ :aggregate_type, :aggregate_id ]
    add_index :event_store, [ :event_type, :occurred_at ]
  end
end
