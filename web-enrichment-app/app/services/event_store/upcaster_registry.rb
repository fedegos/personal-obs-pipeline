# frozen_string_literal: true

module EventStore
  # Registro de upcasters por event_type. Permite aplicar migraciones en lectura.
  class UpcasterRegistry
    NoUpcasterError = Class.new(StandardError)

    class << self
      def register(event_type, upcaster)
        store[event_type.to_s] = upcaster
      end

      def fetch(event_type)
        store[event_type.to_s]
      end

      # Aplica upcast de from_version a to_version. No muta body.
      # Si from_version == to_version devuelve una copia del body.
      # Si from_version < to_version y no hay upcaster registrado, lanza NoUpcasterError.
      def apply_upcast(event_type, body, from_version, to_version)
        return body.deep_dup if from_version >= to_version

        upcaster = fetch(event_type)
        raise NoUpcasterError, "No upcaster for #{event_type} (v#{from_version} -> v#{to_version})" if upcaster.nil?

        upcaster.upcast(body.deep_dup, from_version, to_version)
      end

      def reset!
        @store = nil
      end

      private

      def store
        @store ||= {}
      end
    end
  end
end
