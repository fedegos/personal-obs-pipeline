# frozen_string_literal: true

# Consume domain_events, transacciones_clean y file_results; persiste en event_store (append-only).
# Ver DOCS/EVENT-REPOSITORY-DESIGN.md.
class EventStoreConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      envelope = build_envelope(message)
      next unless envelope

      append_event(envelope)
    end
  rescue StandardError => e
    Karafka.logger.error "EventStoreConsumer error: #{e.message}"
    raise
  end

  private

  def build_envelope(message)
    raw = message.payload
    data = raw.is_a?(String) ? JSON.parse(raw) : raw
    topic_name = topic.name.to_s

    case topic_name
    when "domain_events"    then envelope_from_domain_event(data)
    when "transacciones_clean" then envelope_from_transaccion_clean(data)
    when "file_results"    then envelope_from_file_result(data)
    else
      Karafka.logger.warn "EventStoreConsumer: unknown topic #{topic_name}"
      nil
    end
  end

  def envelope_from_domain_event(data)
    return nil unless data["event_type"] && data["entity_type"] && data["entity_id"] && data["timestamp"]

    occurred_at = Time.zone.parse(data["timestamp"])
    stream_id = "#{data['entity_type']}:#{data['entity_id']}"

    {
      event_type: data["event_type"],
      event_version: 1,
      occurred_at: occurred_at,
      aggregate_type: data["entity_type"],
      aggregate_id: data["entity_id"].to_s,
      stream_id: stream_id,
      metadata: data["metadata"] || {},
      body: data["payload"] || {}
    }
  end

  def envelope_from_transaccion_clean(data)
    return nil unless data["event_id"] && data["fecha"]

    {
      event_type: "transaction.approved",
      event_version: 1,
      occurred_at: Time.zone.parse(data["fecha"].to_s),
      aggregate_type: "Transaction",
      aggregate_id: data["event_id"].to_s,
      stream_id: "Transaction:#{data['event_id']}",
      metadata: {},
      body: data
    }
  end

  def envelope_from_file_result(data)
    return nil unless data["source_file_id"] && data["status"]

    # file_results no trae timestamp; usamos ahora
    {
      event_type: "file.processed",
      event_version: 1,
      occurred_at: Time.current,
      aggregate_type: "SourceFile",
      aggregate_id: data["source_file_id"].to_s,
      stream_id: "SourceFile:#{data['source_file_id']}",
      metadata: {},
      body: data
    }
  end

  def append_event(envelope)
    meta = envelope[:metadata] || {}
    if EventSchemasRegistry.registered?(envelope[:event_type])
      info = EventSchemasRegistry.schema_for(envelope[:event_type], envelope[:event_version] || 1)
      meta = meta.merge("schema" => info[:schema], "schema_deprecated" => info[:deprecated]) if info
    end
    StoredEvent.append!(
      envelope.merge(id: SecureRandom.uuid, causation_id: nil, correlation_id: nil, metadata: meta)
    )
    Karafka.logger.info "Event stored: #{envelope[:event_type]} #{envelope[:stream_id]}"
  rescue ActiveRecord::RecordNotUnique
    Karafka.logger.warn "EventStoreConsumer: duplicate event skipped #{envelope[:stream_id]}"
  end
end
