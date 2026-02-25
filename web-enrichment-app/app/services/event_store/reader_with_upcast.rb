# frozen_string_literal: true

module EventStore
  # Lee un StoredEvent y aplica upcasting si event_version < current_version.
  # Devuelve un hash con los datos listos para exponer (body y event_version actualizados).
  class ReaderWithUpcast
    class << self
      # @param stored_event [StoredEvent]
      # @return [Hash] con :body (posiblemente upcasteado) y :event_version (versión expuesta)
      def read_event(stored_event)
        event_type = stored_event.event_type
        from_version = stored_event.event_version.to_i
        current = EventSchemasRegistry.current_version(event_type) || from_version
        body = stored_event.body || {}

        if from_version < current
          body = UpcasterRegistry.apply_upcast(event_type, body, from_version, current)
          from_version = current
        end

        { body: body, event_version: from_version }
      end
    end
  end
end
