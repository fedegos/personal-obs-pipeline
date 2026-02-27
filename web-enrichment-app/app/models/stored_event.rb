# frozen_string_literal: true

# Registro inmutable en el Event Repository (tabla event_store).
# Solo lectura; no exponer update/destroy. Ver DOCS/EVENT-REPOSITORY-DESIGN.md.
class StoredEvent < ApplicationRecord
  self.table_name = "event_store"
  self.primary_key = "sequence_number"

  def readonly?
    !new_record?
  end

  # Append-only: insertar sin pasar por atributos que Rails pueda omitir (ej. columna "id" no-PK).
  def self.append!(envelope)
    row = {
      id: envelope[:id] || SecureRandom.uuid,
      event_type: envelope[:event_type],
      event_version: envelope[:event_version] || 1,
      occurred_at: envelope[:occurred_at],
      aggregate_type: envelope[:aggregate_type],
      aggregate_id: envelope[:aggregate_id],
      stream_id: envelope[:stream_id],
      causation_id: envelope[:causation_id],
      correlation_id: envelope[:correlation_id],
      metadata: envelope[:metadata] || {},
      body: envelope[:body] || {}
    }
    insert_all([ row ])
  end

  scope :by_stream, ->(stream_id) { where(stream_id: stream_id).order(occurred_at: :asc, sequence_number: :asc) }
  scope :by_occurred_at, ->(from: nil, to: nil) {
    rel = order(occurred_at: :asc, sequence_number: :asc)
    rel = rel.where("occurred_at >= ?", from) if from.present?
    rel = rel.where("occurred_at <= ?", to) if to.present?
    rel
  }
  scope :by_event_type, ->(type) { where(event_type: type) }
end
