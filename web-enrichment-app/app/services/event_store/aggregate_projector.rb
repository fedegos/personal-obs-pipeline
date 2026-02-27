# frozen_string_literal: true

module EventStore
  # Reconstruye el estado de un agregado aplicando eventos en orden.
  # Usado para proyectar snapshots en el visor de eventos.
  # Ver DOCS/EVENT-REPOSITORY-DESIGN.md.
  class AggregateProjector
    class << self
      # Proyecta el estado de un agregado hasta un evento dado.
      # @param stream_id [String] ej. "Transaction:abc123"
      # @param until_sequence_number [Integer, nil] si se pasa, proyecta solo hasta ese evento (inclusive)
      # @return [Hash] estado del agregado
      def project(stream_id, until_sequence_number: nil)
        events = StoredEvent.by_stream(stream_id)
        events = events.where("sequence_number <= ?", until_sequence_number) if until_sequence_number

        state = {}
        events.each do |event|
          body = ReaderWithUpcast.read_event(event)[:body]
          state = apply_event(state, event.event_type, body)
        end
        state
      end

      private

      def apply_event(state, event_type, body)
        case event_type
        when /\.created$/, /\.approved$/
          body.is_a?(Hash) ? body.dup : {}
        when /\.updated$/
          state.merge(body.is_a?(Hash) ? body : {})
        when /\.destroyed$/
          state.merge("_deleted" => true)
        else
          state.merge(body.is_a?(Hash) ? body : {})
        end
      end
    end
  end
end
