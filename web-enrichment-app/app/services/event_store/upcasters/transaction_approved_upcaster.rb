# frozen_string_literal: true

module EventStore
  module Upcasters
    # Convierte body de transaction.approved de v1 a v2.
    # v2 añade el campo "etiquetas" (array vacío si no existe).
    class TransactionApprovedUpcaster
      def upcast(body, from_version, to_version)
        return body.dup if from_version >= to_version

        # Trabajar sobre copia para no mutar el original
        out = body.is_a?(Hash) ? body.deep_dup : body.dup
        return out unless out.is_a?(Hash)

        if from_version == 1 && to_version >= 2
          out["etiquetas"] = out["etiquetas"] || []
        end
        out
      end
    end
  end
end
